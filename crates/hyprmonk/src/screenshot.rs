//! `hyprmonk screenshot`: a region, a window or the screen, taken with grim.
//!
//! A region or a window is picked with slurp over a frozen screen
//! (hyprpicker), so menus and tooltips stay put while choosing. A saved shot
//! opens in satty first (to annotate; Enter saves to the Pictures folder); a
//! copied one goes straight to the clipboard. Either way a notification shows
//! the picture.

use std::fmt::Write as _;
use std::fs;
use std::io::Write as _;
use std::os::unix::ffi::OsStrExt as _;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Output, Stdio};
use std::str::FromStr;
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result, bail};
use serde_json::Value;

/// What to take.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Area {
    /// A rectangle dragged out with the mouse.
    Region,
    /// A window clicked on.
    Window,
    /// The focused screen, at once.
    Screen,
}

impl FromStr for Area {
    type Err = anyhow::Error;

    fn from_str(name: &str) -> Result<Self> {
        match name {
            "region" => Ok(Area::Region),
            "window" => Ok(Area::Window),
            "screen" => Ok(Area::Screen),
            _ => bail!("no such area: {name} (region, window or screen)"),
        }
    }
}

/// Where the picture goes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Target {
    /// Through satty, then a file in the Pictures folder.
    File,
    /// The clipboard, as PNG.
    Clipboard,
}

/// The app name on the notifications.
const APP: &str = "Screenshot";

/// The screenshot mode's key card hides as the bind leaves the mode; the
/// screen freezes only once it is gone, or the card would be in the picture.
const CARD_GONE: Duration = Duration::from_millis(120);

/// hyprpicker needs a moment before its frozen frame covers the screen.
const FROZEN: Duration = Duration::from_millis(200);

/// Takes a screenshot; a selection cancelled with Escape is no error.
///
/// # Errors
///
/// Fails when a tool is missing or fails, or the picture cannot be saved.
pub fn take(area: Area, target: Target) -> Result<()> {
    thread::sleep(CARD_GONE);
    let png = {
        let _freeze = match area {
            Area::Region | Area::Window => Some(Freeze::start()?),
            Area::Screen => None,
        };
        let source = match area {
            Area::Region => select(&["-d"], "")?.map(Source::Geometry),
            Area::Window => select(&["-r"], &window_boxes()?)?.map(Source::Geometry),
            Area::Screen => Some(Source::Output(focused_output()?)),
        };
        let Some(source) = source else {
            return Ok(());
        };
        capture(&source)?
    };
    match target {
        Target::File => save(&png),
        Target::Clipboard => copy(&png),
    }
}

/// Tells the user a screenshot failed: the bind runs with no terminal to
/// print to.
pub fn report(err: &anyhow::Error) {
    // Nothing more to do if even this fails.
    let _ = Command::new("notify-send")
        .args(["--app-name", APP, "--icon", "dialog-error"])
        .args(["Screenshot failed", &format!("{err:#}")])
        .status();
}

/// The screen held still while a selection is made; thawed when dropped.
struct Freeze(Child);

impl Freeze {
    fn start() -> Result<Self> {
        let child = Command::new("hyprpicker")
            .args(["--render-inactive", "--no-zoom"])
            .stdout(Stdio::null())
            .spawn()
            .context("running hyprpicker (to freeze the screen)")?;
        thread::sleep(FROZEN);
        Ok(Freeze(child))
    }
}

impl Drop for Freeze {
    fn drop(&mut self) {
        // Best effort: it may already be gone.
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

/// What grim captures.
enum Source {
    /// `x,y wxh`, in layout coordinates.
    Geometry(String),
    /// A monitor's name.
    Output(String),
}

/// Runs slurp, feeding it `boxes`; `None` when the selection is cancelled.
pub(crate) fn select(flags: &[&str], boxes: &str) -> Result<Option<String>> {
    let output = run_with_input(
        Command::new("slurp").args(flags).stdout(Stdio::piped()),
        boxes.as_bytes(),
    )
    .context("running slurp")?;
    if !output.status.success() {
        // slurp says "selection cancelled" and exits 1 on Escape.
        return Ok(None);
    }
    let geometry = String::from_utf8(output.stdout).context("slurp printed no text")?;
    Ok(Some(geometry.trim().to_owned()))
}

fn capture(source: &Source) -> Result<Vec<u8>> {
    let mut grim = Command::new("grim");
    match source {
        Source::Geometry(geometry) => grim.args(["-g", geometry]),
        Source::Output(name) => grim.args(["-o", name]),
    };
    let output = grim.arg("-").output().context("running grim")?;
    if !output.status.success() {
        bail!("grim: {}", String::from_utf8_lossy(&output.stderr).trim());
    }
    Ok(output.stdout)
}

/// Opens the shot in satty; once it is saved there, says so.
fn save(png: &[u8]) -> Result<()> {
    let folder = user_folder("PICTURES", "Pictures").join("Screenshots");
    fs::create_dir_all(&folder).with_context(|| format!("creating {}", folder.display()))?;
    let path = folder.join(format!("Screenshot_{}.png", timestamp(FILE_TIME)?));
    let status = run_with_input(
        Command::new("satty")
            .args(["--filename", "-", "--output-filename"])
            .arg(&path)
            .args(["--early-exit", "all", "--actions-on-enter", "save-to-file"])
            .args(["--copy-command", "wl-copy", "--disable-notifications"]),
        png,
    )
    .context("running satty")?
    .status;
    if !status.success() {
        bail!("satty exited with {status}");
    }
    // Closed without saving (or only copied): nothing to show.
    if !path.exists() {
        return Ok(());
    }
    offer(APP, "Screenshot saved", &path, Some(&path))
}

/// Says a file was saved, with its picture, and waits to open it or show it
/// in the file manager.
pub(crate) fn offer(app: &str, summary: &str, path: &Path, picture: Option<&Path>) -> Result<()> {
    let name = path
        .file_name()
        .map_or_else(String::new, |name| name.to_string_lossy().into_owned());
    let action = notify(
        app,
        summary,
        &name,
        picture,
        &["default=Open", "open=Open", "folder=Show in folder"],
    )?;
    match action.as_str() {
        "default" | "open" => spawn(Command::new("xdg-open").arg(path)),
        "folder" => spawn(Command::new("dbus-send").args([
            "--session",
            "--dest=org.freedesktop.FileManager1",
            "--type=method_call",
            "/org/freedesktop/FileManager1",
            "org.freedesktop.FileManager1.ShowItems",
            &format!("array:string:{}", file_url(path)),
            "string:",
        ])),
        _ => Ok(()),
    }
}

/// Puts the shot on the clipboard and shows it (from a copy in the runtime
/// folder, gone at logout).
fn copy(png: &[u8]) -> Result<()> {
    // wl-copy leaves a process behind to serve the clipboard: it must not
    // hold a pipe of ours open, or the wait for its output never ends.
    let status = run_with_input(
        Command::new("wl-copy")
            .args(["--type", "image/png"])
            .stdout(Stdio::null())
            .stderr(Stdio::null()),
        png,
    )
    .context("running wl-copy")?
    .status;
    if !status.success() {
        bail!("wl-copy exited with {status}");
    }
    let runtime = std::env::var_os("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR is not set")?;
    let folder = Path::new(&runtime).join("hyprmonk/screenshots");
    fs::create_dir_all(&folder).with_context(|| format!("creating {}", folder.display()))?;
    let preview = folder.join(format!("{}.png", timestamp(PREVIEW_TIME)?));
    fs::write(&preview, png).with_context(|| format!("writing {}", preview.display()))?;
    notify(APP, "Copied to clipboard", "", Some(&preview), &[])?;
    Ok(())
}

/// Sends a notification with the picture; with actions, waits for one and
/// returns its name (empty when it is dismissed).
fn notify(
    app: &str,
    summary: &str,
    body: &str,
    picture: Option<&Path>,
    actions: &[&str],
) -> Result<String> {
    let mut command = Command::new("notify-send");
    command.args(["--app-name", app, "--icon", "camera-photo"]);
    if let Some(picture) = picture {
        command
            .arg(format!("--hint=string:image-path:{}", picture.display()))
            // The shell's cards show this picture large.
            .arg("--hint=boolean:x-hyprmonk-preview:true");
    }
    for action in actions {
        command.arg(format!("--action={action}"));
    }
    let output = command
        .args([summary, body])
        .output()
        .context("running notify-send")?;
    if !output.status.success() {
        bail!(
            "notify-send: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
}

/// The visible windows as slurp boxes (`x,y wxh` lines), the most recently
/// focused first.
fn window_boxes() -> Result<String> {
    Ok(boxes(&hyprctl("monitors")?, &hyprctl("clients")?))
}

fn boxes(monitors: &Value, clients: &Value) -> String {
    let shown: Vec<i64> = as_list(monitors)
        .iter()
        .flat_map(|monitor| {
            [
                &monitor["activeWorkspace"]["id"],
                &monitor["specialWorkspace"]["id"],
            ]
        })
        .filter_map(Value::as_i64)
        .filter(|&id| id != 0)
        .collect();
    let mut windows: Vec<&Value> = as_list(clients)
        .iter()
        .filter(|window| {
            window["mapped"].as_bool() == Some(true) && window["hidden"].as_bool() != Some(true)
        })
        .filter(|window| {
            window["workspace"]["id"]
                .as_i64()
                .is_some_and(|id| shown.contains(&id))
        })
        .collect();
    windows.sort_by_key(|window| window["focusHistoryID"].as_i64().unwrap_or(i64::MAX));
    let mut lines = String::new();
    for window in windows {
        let number = |field: &str, index: usize| window[field][index].as_i64().unwrap_or(0);
        let _ = writeln!(
            lines,
            "{},{} {}x{}",
            number("at", 0),
            number("at", 1),
            number("size", 0),
            number("size", 1)
        );
    }
    lines
}

fn focused_output() -> Result<String> {
    let monitors = hyprctl("monitors")?;
    as_list(&monitors)
        .iter()
        .find(|monitor| monitor["focused"].as_bool() == Some(true))
        .and_then(|monitor| monitor["name"].as_str())
        .map(str::to_owned)
        .context("Hyprland reports no focused monitor")
}

fn as_list(value: &Value) -> &[Value] {
    value.as_array().map_or(&[], Vec::as_slice)
}

fn hyprctl(what: &str) -> Result<Value> {
    let output = Command::new("hyprctl")
        .args([what, "-j"])
        .output()
        .context("running hyprctl")?;
    if !output.status.success() {
        bail!(
            "hyprctl {what}: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }
    serde_json::from_slice(&output.stdout).with_context(|| format!("reading hyprctl {what}"))
}

/// A folder of the user's (xdg-user-dirs), else the one by that name in the
/// home folder.
pub(crate) fn user_folder(kind: &str, fallback: &str) -> PathBuf {
    let named = Command::new("xdg-user-dir")
        .arg(kind)
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_owned())
        .filter(|path| !path.is_empty());
    named.map_or_else(
        || PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(fallback),
        PathBuf::from,
    )
}

/// A saved shot's time: 2026-10-28_19-04-11.
pub(crate) const FILE_TIME: &str = "+%Y-%m-%d_%H-%M-%S";

/// A copied shot's preview, with milliseconds: two copies within a second
/// must not share a file (the first notification would show the second).
const PREVIEW_TIME: &str = "+%Y-%m-%d_%H-%M-%S-%3N";

/// The local time in `format`, from `date` (std has no local time).
pub(crate) fn timestamp(format: &str) -> Result<String> {
    let output = Command::new("date")
        .arg(format)
        .output()
        .context("running date")?;
    if !output.status.success() {
        bail!("date exited with {}", output.status);
    }
    let stamp = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    if stamp.is_empty() {
        bail!("date printed nothing");
    }
    Ok(stamp)
}

/// `path` as a `file://` URL: every byte but the unreserved ones and `/` is
/// percent-encoded (RFC 3986), so spaces, `#` and non-ASCII names survive.
fn file_url(path: &Path) -> String {
    let mut url = String::from("file://");
    for &byte in path.as_os_str().as_bytes() {
        if byte.is_ascii_alphanumeric() || b"/-._~".contains(&byte) {
            url.push(char::from(byte));
        } else {
            let _ = write!(url, "%{byte:02X}");
        }
    }
    url
}

/// Runs a command with `input` on its stdin, collecting its stdout when the
/// command pipes it. All of the input is written before any output is read:
/// fine for today's callers (slurp gets a few lines and prints one), but a
/// command that fills its output pipe before reading all its input would
/// wait forever.
fn run_with_input(command: &mut Command, input: &[u8]) -> Result<Output> {
    let mut child = command.stdin(Stdio::piped()).spawn()?;
    let mut stdin = child.stdin.take().context("no stdin")?;
    // A tool that stops reading early (cancelled) closes the pipe: not an error.
    match stdin.write_all(input) {
        Err(err) if err.kind() != std::io::ErrorKind::BrokenPipe => return Err(err.into()),
        _ => {}
    }
    drop(stdin);
    Ok(child.wait_with_output()?)
}

/// Starts a command and lets it run on its own.
fn spawn(command: &mut Command) -> Result<()> {
    command
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .spawn()
        .with_context(|| format!("running {}", command.get_program().to_string_lossy()))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn areas_parse_by_name() {
        assert_eq!("region".parse::<Area>().ok(), Some(Area::Region));
        assert_eq!("window".parse::<Area>().ok(), Some(Area::Window));
        assert_eq!("screen".parse::<Area>().ok(), Some(Area::Screen));
        assert!("output".parse::<Area>().is_err());
    }

    #[test]
    fn boxes_are_the_visible_windows_last_focused_first() {
        let monitors = serde_json::json!([
            { "activeWorkspace": { "id": 1 }, "specialWorkspace": { "id": 0 } }
        ]);
        let clients = serde_json::json!([
            { "mapped": true, "hidden": false, "workspace": { "id": 1 }, "focusHistoryID": 1,
              "at": [10, 20], "size": [300, 200] },
            { "mapped": true, "hidden": false, "workspace": { "id": 2 }, "focusHistoryID": 2,
              "at": [0, 0], "size": [5, 5] },
            { "mapped": true, "hidden": true, "workspace": { "id": 1 }, "focusHistoryID": 3,
              "at": [0, 0], "size": [6, 6] },
            { "mapped": true, "hidden": false, "workspace": { "id": 1 }, "focusHistoryID": 0,
              "at": [400, 20], "size": [500, 600] }
        ]);
        assert_eq!(
            boxes(&monitors, &clients),
            "400,20 500x600\n10,20 300x200\n"
        );
    }

    #[test]
    fn file_urls_are_percent_encoded() {
        assert_eq!(
            file_url(Path::new("/home/me/My Pictures/#1/café.png")),
            "file:///home/me/My%20Pictures/%231/caf%C3%A9.png"
        );
        assert_eq!(
            file_url(Path::new("/tmp/Screenshot_2026-10-28_19-04-11.png")),
            "file:///tmp/Screenshot_2026-10-28_19-04-11.png"
        );
    }

    #[test]
    fn boxes_of_nothing_are_empty() {
        assert_eq!(boxes(&Value::Null, &Value::Null), "");
    }
}
