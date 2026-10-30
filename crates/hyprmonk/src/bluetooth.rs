//! `hyprmonk bluetooth-agent`: a `BlueZ` pairing agent, kept running by the
//! shell (`services/Bluez.qml`). `BlueZ` asks it what a pairing needs, such as a
//! code to confirm; each request goes to the shell as one JSON line on stdout
//! and its answer comes back as one on stdin. Every decision is the shell's.

use std::collections::HashMap;
use std::io::{self, BufRead, Write};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use anyhow::{Context, Result};
use futures_channel::oneshot;
use serde_json::{Value, json};
use zbus::blocking::Proxy;
use zbus::blocking::connection::Builder;
use zbus::interface;
use zbus::zvariant::{ObjectPath, OwnedObjectPath};

const AGENT_PATH: &str = "/org/hyprmonk/BluetoothAgent";
/// Can show a code and take one typed: what lets every kind of device pair.
const CAPABILITY: &str = "KeyboardDisplay";

/// The shell's reply to a request.
#[derive(Debug, PartialEq, Eq)]
struct Answer {
    id: u64,
    accepted: bool,
    value: String,
}

impl Answer {
    /// `{"id": 1, "accepted": true, "value": "1234"}`; `value` is optional.
    fn parse(line: &str) -> Option<Self> {
        let answer: Value = serde_json::from_str(line).ok()?;
        Some(Self {
            id: answer["id"].as_u64()?,
            accepted: answer["accepted"].as_bool()?,
            value: answer["value"].as_str().unwrap_or_default().to_owned(),
        })
    }
}

/// What `BlueZ` gets back when the shell refuses, or the request goes away.
#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "org.bluez.Error")]
enum AgentError {
    #[zbus(error)]
    ZBus(zbus::Error),
    Rejected,
    Canceled,
}

type Pending = Arc<Mutex<HashMap<u64, oneshot::Sender<Answer>>>>;

struct Agent {
    pending: Pending,
    next_id: AtomicU64,
}

impl Agent {
    /// Sends the shell a request and waits for its answer.
    async fn ask(&self, mut request: Value) -> Result<String, AgentError> {
        let id = self.next_id.fetch_add(1, Ordering::Relaxed);
        let (sender, receiver) = oneshot::channel();
        self.pending
            .lock()
            .expect("lock poisoned")
            .insert(id, sender);
        request["id"] = json!(id);
        tell(&request);
        match receiver.await {
            Ok(answer) if answer.accepted => Ok(answer.value),
            Ok(_) => Err(AgentError::Rejected),
            Err(oneshot::Canceled) => Err(AgentError::Canceled),
        }
    }
}

/// One line for the shell. If it has gone, stdin ends and so does this.
fn tell(message: &Value) {
    drop(writeln!(io::stdout(), "{message}"));
}

/// The `org.bluez.Agent1` interface, as in `BlueZ`'s `doc/org.bluez.Agent.rst`.
#[interface(name = "org.bluez.Agent1")]
#[expect(
    clippy::unused_self,
    clippy::needless_pass_by_value,
    reason = "the D-Bus interface sets these signatures"
)]
impl Agent {
    fn release(&self) {}

    async fn request_pin_code(&self, device: OwnedObjectPath) -> Result<String, AgentError> {
        self.ask(json!({ "kind": "pin", "device": device.as_str() }))
            .await
    }

    fn display_pin_code(&self, device: OwnedObjectPath, pincode: String) {
        tell(&json!({ "kind": "show-pin", "device": device.as_str(), "code": pincode }));
    }

    async fn request_passkey(&self, device: OwnedObjectPath) -> Result<u32, AgentError> {
        let code = self
            .ask(json!({ "kind": "passkey", "device": device.as_str() }))
            .await?;
        code.parse().map_err(|_| AgentError::Rejected)
    }

    fn display_passkey(&self, device: OwnedObjectPath, passkey: u32, entered: u16) {
        tell(
            &json!({ "kind": "show-passkey", "device": device.as_str(), "code": passkey, "entered": entered }),
        );
    }

    async fn request_confirmation(
        &self,
        device: OwnedObjectPath,
        passkey: u32,
    ) -> Result<(), AgentError> {
        let request = json!({ "kind": "confirmation", "device": device.as_str(), "code": passkey });
        self.ask(request).await.map(drop)
    }

    async fn request_authorization(&self, device: OwnedObjectPath) -> Result<(), AgentError> {
        self.ask(json!({ "kind": "authorization", "device": device.as_str() }))
            .await
            .map(drop)
    }

    async fn authorize_service(
        &self,
        device: OwnedObjectPath,
        uuid: String,
    ) -> Result<(), AgentError> {
        let request = json!({ "kind": "service", "device": device.as_str(), "uuid": uuid });
        self.ask(request).await.map(drop)
    }

    /// Dropping the senders ends every wait with `Canceled`.
    fn cancel(&self) {
        self.pending.lock().expect("lock poisoned").clear();
        tell(&json!({ "kind": "cancel" }));
    }
}

/// Registers with `BlueZ` as the default agent and relays until stdin ends,
/// which is the shell stopping it or going away.
pub fn run() -> Result<()> {
    let pending = Pending::default();
    let agent = Agent {
        pending: Arc::clone(&pending),
        next_id: AtomicU64::new(1),
    };
    let connection = Builder::system()
        .context("connecting to the system bus")?
        .serve_at(AGENT_PATH, agent)
        .context("offering the agent")?
        .build()
        .context("connecting to the system bus")?;

    let path = ObjectPath::try_from(AGENT_PATH).context("the agent's path")?;
    let manager = Proxy::new(
        &connection,
        "org.bluez",
        "/org/bluez",
        "org.bluez.AgentManager1",
    )
    .context("reaching BlueZ")?;
    let _: () = manager
        .call("RegisterAgent", &(&path, CAPABILITY))
        .context("registering with BlueZ")?;
    let _: () = manager
        .call("RequestDefaultAgent", &(&path,))
        .context("becoming BlueZ's default agent")?;

    for line in io::stdin().lock().lines() {
        let line = line.context("reading the shell's answers")?;
        let Some(answer) = Answer::parse(&line) else {
            eprintln!("hyprmonk: not an answer: {line}");
            continue;
        };
        // None: `BlueZ` cancelled it first, so the answer has nowhere to go.
        let sender = pending.lock().expect("lock poisoned").remove(&answer.id);
        if let Some(sender) = sender {
            drop(sender.send(answer));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_an_answer_with_a_value() {
        assert_eq!(
            Answer::parse(r#"{"id": 4, "accepted": true, "value": "0000"}"#),
            Some(Answer {
                id: 4,
                accepted: true,
                value: "0000".to_owned()
            })
        );
    }

    #[test]
    fn a_value_is_optional() {
        assert_eq!(
            Answer::parse(r#"{"id": 4, "accepted": false}"#),
            Some(Answer {
                id: 4,
                accepted: false,
                value: String::new()
            })
        );
    }

    #[test]
    fn anything_else_is_no_answer() {
        assert_eq!(Answer::parse("yes"), None);
        assert_eq!(Answer::parse(r#"{"accepted": true}"#), None);
        assert_eq!(Answer::parse(r#"{"id": 4}"#), None);
    }
}
