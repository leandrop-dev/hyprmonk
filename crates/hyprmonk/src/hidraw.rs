//! Finding HID interfaces through sysfs and exchanging reports over `/dev/hidraw*`.

use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{Context, Result};
use rustix::event::{PollFd, PollFlags, Timespec, poll};

/// The kernel's list of hidraw nodes, one directory per `/dev/hidrawN`.
pub const SYSFS_CLASS: &str = "/sys/class/hidraw";

/// One HID interface of a USB device: its vendor and product IDs and its interface number.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Address {
    pub vendor: u16,
    pub product: u16,
    pub interface: u8,
}

/// Returns the `/dev` node of every hidraw interface at `address`, sorted by name.
///
/// `class_dir` is normally [`SYSFS_CLASS`]. A node that disappears while it is
/// being looked at (the device was unplugged) is skipped.
///
/// # Errors
///
/// Fails when `class_dir` exists but cannot be listed.
pub fn find(class_dir: &Path, address: Address) -> Result<Vec<PathBuf>> {
    let entries = match fs::read_dir(class_dir) {
        Ok(entries) => entries,
        Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(err) => return Err(err).with_context(|| format!("listing {}", class_dir.display())),
    };

    let mut nodes = Vec::new();
    for entry in entries.flatten() {
        let Ok(uevent) = fs::read_to_string(entry.path().join("device/uevent")) else {
            continue;
        };
        if parse_uevent(&uevent) == Some(address) {
            nodes.push(Path::new("/dev").join(entry.file_name()));
        }
    }
    nodes.sort();
    Ok(nodes)
}

/// Reads the address from a HID device's uevent: vendor and product from
/// `HID_ID=BUS:VENDOR:PRODUCT`, the interface from `HID_PHYS=...:/inputN`.
fn parse_uevent(uevent: &str) -> Option<Address> {
    let mut ids = None;
    let mut interface = None;
    for line in uevent.lines() {
        if let Some(value) = line.strip_prefix("HID_ID=") {
            let mut parts = value.split(':').skip(1);
            let vendor = u16::from_str_radix(parts.next()?, 16).ok()?;
            let product = u16::from_str_radix(parts.next()?, 16).ok()?;
            ids = Some((vendor, product));
        } else if let Some(value) = line.strip_prefix("HID_PHYS=") {
            interface = value.rsplit_once("/input")?.1.parse().ok();
        }
    }
    let (vendor, product) = ids?;
    Some(Address {
        vendor,
        product,
        interface: interface?,
    })
}

/// An open hidraw node.
#[derive(Debug)]
pub struct Device {
    file: File,
    path: PathBuf,
}

impl Device {
    /// Opens `path` for reading and writing reports.
    ///
    /// # Errors
    ///
    /// Fails when the node cannot be opened; without the udev rule from
    /// `udev/` only root may open it.
    pub fn open(path: &Path) -> Result<Self> {
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .open(path)
            .with_context(|| match path.metadata() {
                Ok(_) => format!(
                    "opening {} (is the udev rule installed? see `install.sh udev`)",
                    path.display()
                ),
                Err(_) => format!("opening {}", path.display()),
            })?;
        Ok(Self {
            file,
            path: path.to_owned(),
        })
    }

    /// Sends one output report; its first byte is the report ID.
    ///
    /// # Errors
    ///
    /// Fails when the kernel rejects the write.
    pub fn write_report(&mut self, report: &[u8]) -> Result<()> {
        self.file
            .write_all(report)
            .with_context(|| format!("writing to {}", self.path.display()))
    }

    /// Waits up to `timeout` for the next input report and copies it into `buf`.
    ///
    /// Returns the report's length, or `None` when nothing arrived in time.
    ///
    /// # Errors
    ///
    /// Fails when waiting or reading fails, for example after an unplug.
    pub fn read_report(&mut self, buf: &mut [u8], timeout: Duration) -> Result<Option<usize>> {
        let timeout = Timespec::try_from(timeout).context("timeout out of range")?;
        let ready = {
            let mut fds = [PollFd::new(&self.file, PollFlags::IN)];
            poll(&mut fds, Some(&timeout))
                .with_context(|| format!("waiting on {}", self.path.display()))?
        };
        if ready == 0 {
            return Ok(None);
        }
        let len = self
            .file
            .read(buf)
            .with_context(|| format!("reading from {}", self.path.display()))?;
        Ok(Some(len))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const RIVAL_3_INTERFACE_3: &str = "DRIVER=hid-generic\n\
        HID_ID=0003:00001038:00001830\n\
        HID_NAME=SteelSeries SteelSeries Rival 3 Wireless\n\
        HID_PHYS=usb-0000:00:14.0-4.4/input3\n\
        HID_UNIQ=\n";

    const RIVAL_3: Address = Address {
        vendor: 0x1038,
        product: 0x1830,
        interface: 3,
    };

    #[test]
    fn parses_ids_and_interface() {
        assert_eq!(parse_uevent(RIVAL_3_INTERFACE_3), Some(RIVAL_3));
    }

    #[test]
    fn rejects_incomplete_uevents() {
        for uevent in [
            "HID_ID=0003:00001038:00001830\n",
            "HID_PHYS=usb-0000:00:14.0-4.4/input3\n",
            "HID_ID=garbage\nHID_PHYS=usb-0000:00:14.0-4.4/input3\n",
            "HID_ID=0003:00001038:00001830\nHID_PHYS=usb-0000:00:14.0-4.4\n",
        ] {
            assert_eq!(parse_uevent(uevent), None, "uevent {uevent:?}");
        }
    }

    #[test]
    fn finds_only_the_matching_interface() {
        let root = std::env::temp_dir().join(format!("hyprmonk-hidraw-{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        let node = |name: &str, uevent: &str| {
            let dir = root.join(name).join("device");
            fs::create_dir_all(&dir).expect("creating the fake sysfs tree");
            fs::write(dir.join("uevent"), uevent).expect("writing a fake uevent");
        };
        node("hidraw4", RIVAL_3_INTERFACE_3);
        node(
            "hidraw2",
            &RIVAL_3_INTERFACE_3.replace("/input3", "/input2"),
        );
        node(
            "hidraw9",
            "HID_ID=0003:00001038:000022A1\nHID_PHYS=usb-0000:00:14.0-3/input3\n",
        );
        fs::create_dir_all(root.join("hidraw7")).expect("creating a node without a device");

        let found = find(&root, RIVAL_3).expect("listing the fake sysfs tree");
        fs::remove_dir_all(&root).expect("removing the fake sysfs tree");

        assert_eq!(found, [PathBuf::from("/dev/hidraw4")]);
    }

    #[test]
    fn missing_class_dir_means_no_devices() {
        let found =
            find(Path::new("/nonexistent/hidraw"), RIVAL_3).expect("a missing dir is not an error");
        assert_eq!(found, Vec::<PathBuf>::new());
    }
}
