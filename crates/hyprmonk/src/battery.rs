//! `hyprmonk battery`: the charge of devices UPower cannot see.

use std::fmt::Write as _;
use std::path::Path;

use anyhow::Result;

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
            let items: Vec<String> = readings.iter().map(json_object).collect();
            let _ = writeln!(out, "[{}]", items.join(","));
        }
    }
    out
}

fn json_object(reading: &Reading) -> String {
    let (percent, charging) = match reading.charge {
        Some(charge) => (charge.percent.to_string(), charge.charging.to_string()),
        None => ("null".to_owned(), "null".to_owned()),
    };
    format!(
        r#"{{"name":"{}","kind":"{}","percent":{percent},"charging":{charging}}}"#,
        json_escape(reading.name),
        reading.kind.as_str()
    )
}

fn json_escape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            c if c.is_control() => {
                let _ = write!(out, "\\u{:04x}", u32::from(c));
            }
            c => out.push(c),
        }
    }
    out
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
    fn json_escapes_names_and_uses_null_when_asleep() {
        assert_eq!(
            render(&readings(), Format::Json),
            concat!(
                r#"[{"name":"Mouse","kind":"mouse","percent":13,"charging":false},"#,
                r#"{"name":"Pad \"2\"","kind":"mouse","percent":90,"charging":true},"#,
                r#"{"name":"Asleep","kind":"mouse","percent":null,"charging":null}]"#,
                "\n"
            )
        );
    }

    #[test]
    fn no_devices_is_an_empty_array() {
        assert_eq!(render(&[], Format::Json), "[]\n");
        assert_eq!(render(&[], Format::Text), "");
    }
}
