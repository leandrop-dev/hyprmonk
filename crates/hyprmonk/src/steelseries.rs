//! SteelSeries wireless mice, read through their USB receiver.
//!
//! The protocol comes from rivalcfg (`rivalcfg/devices/rival3_wireless.py`):
//! write the battery command to the vendor interface, then read three bytes
//! back, the level in percent first and the charging flag third.

use std::time::Duration;

use anyhow::Result;

use crate::battery::Charge;
use crate::hidraw::{Address, Device};

/// A supported mouse: its name and the HID interface that answers commands.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Mouse {
    pub name: &'static str,
    pub address: Address,
}

/// The Rival 3 Wireless on its 2.4 GHz receiver.
pub const RIVAL_3_WIRELESS: Mouse = Mouse {
    name: "SteelSeries Rival 3 Wireless",
    address: Address {
        vendor: 0x1038,
        product: 0x1830,
        interface: 3,
    },
};

/// Every mouse `hyprmonk battery` looks for.
pub const MICE: &[Mouse] = &[RIVAL_3_WIRELESS];

/// Report ID 0, then the battery command `AA 01`.
const BATTERY_QUERY: [u8; 3] = [0x00, 0xAA, 0x01];

/// How long the receiver gets to answer; rivalcfg waits the same 200 ms.
const ANSWER_TIMEOUT: Duration = Duration::from_millis(200);

/// Asks the mouse behind `device` for its battery.
///
/// Returns `None` when the receiver gives no valid answer, which is what it
/// does while the mouse is off or asleep.
///
/// # Errors
///
/// Fails when the query cannot be sent or the answer cannot be read.
pub fn read_battery(device: &mut Device) -> Result<Option<Charge>> {
    device.write_report(&BATTERY_QUERY)?;
    let mut answer = [0; 64];
    let Some(len) = device.read_report(&mut answer, ANSWER_TIMEOUT)? else {
        return Ok(None);
    };
    Ok(parse_battery(&answer[..len]))
}

fn parse_battery(answer: &[u8]) -> Option<Charge> {
    let [percent, _, charging, ..] = *answer else {
        return None;
    };
    (percent <= 100).then_some(Charge {
        percent,
        charging: charging != 0,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_level_and_charging() {
        assert_eq!(
            parse_battery(&[13, 0, 0]),
            Some(Charge {
                percent: 13,
                charging: false
            })
        );
        assert_eq!(
            parse_battery(&[80, 0, 1, 0, 0]),
            Some(Charge {
                percent: 80,
                charging: true
            })
        );
    }

    #[test]
    fn rejects_short_or_out_of_range_answers() {
        for answer in [&[][..], &[13, 0][..], &[101, 0, 0][..], &[0xFF, 0, 0][..]] {
            assert_eq!(parse_battery(answer), None, "answer {answer:?}");
        }
    }
}
