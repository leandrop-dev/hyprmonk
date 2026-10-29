//! `hyprmonk battery`: the charge of devices UPower cannot see.

use std::fmt::Write as _;
use std::path::Path;

use anyhow::Result;
use serde_json::{Value, json};

use crate::hidraw::{self, Device};
use crate::steelseries;

/// A battery's state as the device reports it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Charge {
    pub percent: u8,
    pub charging: bool,
}

/// What a device is, so the shell can show a fitting icon.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Mouse,
}

impl Kind {
    /// The name in the JSON output.
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Kind::Mouse => "mouse",
        }
    }
}

/// One device found, with its charge; `None` while it is off or asleep.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Reading {
    pub name: &'static str,
    pub kind: Kind,
    pub charge: Option<Charge>,
}

/// How `battery` prints what it found.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Format {
    /// One `name: 13%` line per device.
    Text,
    /// A JSON array for the shell:
    /// `[{"name": .., "kind": "mouse", "percent": .., "charging": ..}]`.
    Json,
}

/// Reads every supported device that is plugged in.
///
/// # Errors
///
/// Fails when a device is present but cannot be opened or asked.
pub fn read_all() -> Result<Vec<Reading>> {
    let mut readings = Vec::new();
    for mouse in steelseries::MICE {
        for node in hidraw::find(Path::new(hidraw::SYSFS_CLASS), mouse.address)? {
            let mut device = Device::open(&node)?;
            readings.push(Reading {
                name: mouse.name,
                kind: Kind::Mouse,
                charge: steelseries::read_battery(&mut device)?,
            });
        }
    }
    Ok(readings)
}

/// Renders `readings` in `format`, ending with a newline.
#[must_use]
pub fn render(readings: &[Reading], format: Format) -> String {
    let mut out = String::new();
    match format {
        Format::Text => {
            for reading in readings {
                let state = match reading.charge {
                    Some(Charge {
                        percent,
                        charging: true,
                    }) => format!("{percent}% (charging)"),
                    Some(Charge {
                        percent,
                        charging: false,
                    }) => format!("{percent}%"),
                    None => "off or asleep".to_owned(),
                };
                let _ = writeln!(out, "{}: {state}", reading.name);
            }
        }
        Format::Json => {
            let items: Vec<Value> = readings.iter().map(json_object).collect();
            let _ = writeln!(out, "{}", Value::Array(items));
        }
    }
    out
}

fn json_object(reading: &Reading) -> Value {
    json!({
        "name": reading.name,
        "kind": reading.kind.as_str(),
        "percent": reading.charge.map(|charge| charge.percent),
        "charging": reading.charge.map(|charge| charge.charging),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn readings() -> Vec<Reading> {
        vec![
            Reading {
                name: "Mouse",
                kind: Kind::Mouse,
                charge: Some(Charge {
                    percent: 13,
                    charging: false,
                }),
            },
            Reading {
                name: "Pad \"2\"",
                kind: Kind::Mouse,
                charge: Some(Charge {
                    percent: 90,
                    charging: true,
                }),
            },
            Reading {
                name: "Asleep",
                kind: Kind::Mouse,
                charge: None,
            },
        ]
    }

    #[test]
    fn text_has_one_line_per_device() {
        assert_eq!(
            render(&readings(), Format::Text),
            "Mouse: 13%\nPad \"2\": 90% (charging)\nAsleep: off or asleep\n"
        );
    }

    #[test]
    fn json_is_one_line_with_null_when_asleep() {
        let out = render(&readings(), Format::Json);
        assert!(out.ends_with("]\n") && out.lines().count() == 1, "{out:?}");
        let parsed: Value = serde_json::from_str(&out).expect("valid JSON");
        assert_eq!(
            parsed,
            json!([
                { "name": "Mouse", "kind": "mouse", "percent": 13, "charging": false },
                { "name": "Pad \"2\"", "kind": "mouse", "percent": 90, "charging": true },
                { "name": "Asleep", "kind": "mouse", "percent": null, "charging": null }
            ])
        );
    }

    #[test]
    fn no_devices_is_an_empty_array() {
        assert_eq!(render(&[], Format::Json), "[]\n");
        assert_eq!(render(&[], Format::Text), "");
    }
}
