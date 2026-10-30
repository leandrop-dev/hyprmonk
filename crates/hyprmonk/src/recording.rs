//! `hyprmonk record`: a screen with its sound to the Videos folder, by GPU
//! Screen Recorder. The shell runs it and stops it with SIGINT, which is why
//! this becomes the recorder rather than waiting for it; `hyprmonk
//! recording-saved` then says where it went.

use std::fs;
use std::io::{self, Write as _};
use std::os::unix::process::CommandExt as _;
use std::path::Path;
use std::process::Command;

use anyhow::{Context, Result, bail};

use crate::screenshot;

const RECORDER: &str = "gpu-screen-recorder";

/// Prints the file it will write, then becomes the recorder. Returns only if
/// that fails.
///
/// # Errors
///
/// Fails when the folder cannot be made or the recorder cannot start.
pub fn start(monitor: &str) -> Result<()> {
    let folder = screenshot::user_folder("VIDEOS", "Videos").join("Recordings");
    fs::create_dir_all(&folder).with_context(|| format!("creating {}", folder.display()))?;
    let stamp = screenshot::timestamp(screenshot::FILE_TIME)?;
    let path = folder.join(format!("Recording_{stamp}.mp4"));
    let info = Command::new(RECORDER)
        .arg("--info")
        .output()
        .with_context(|| format!("running {RECORDER}"))?;
    let info = String::from_utf8_lossy(&info.stdout);

    let mut stdout = io::stdout();
    writeln!(stdout, "{}", path.display())?;
    stdout.flush()?;

    let err = Command::new(RECORDER)
        .args([
            "-w",
            monitor,
            "-f",
            "60",
            "-a",
            "default_output",
            "-v",
            "no",
        ])
        .args(encoder(&info))
        .arg("-o")
        .arg(&path)
        .exec();
    Err(err).with_context(|| format!("running {RECORDER}"))
}

/// The cheapest encoder `--info` lists. Plain `h264` is NVENC or VAAPI; the
/// `FFmpeg` here wants a newer NVENC than the 580xx driver has, and then it is
/// missing while Vulkan's still works, at about a quarter of the software
/// encoder's processor time.
fn encoder(info: &str) -> &'static [&'static str] {
    let listed = |codec| info.lines().any(|line| line == codec);
    if listed("h264") {
        &["-k", "h264"]
    } else if listed("h264_vulkan") {
        &["-k", "h264_vulkan"]
    } else {
        &["-k", "h264", "-encoder", "cpu"]
    }
}

/// Offers a finished recording, with its first frame when one can be had.
///
/// # Errors
///
/// Fails when the file is not there or the notification cannot be sent.
pub fn saved(file: &Path) -> Result<()> {
    if !file.exists() {
        bail!("{} is not there", file.display());
    }
    let picture = first_frame(file).ok();
    screenshot::offer(
        "Screen recording",
        "Recording saved",
        file,
        picture.as_deref(),
    )
}

/// The first frame as a PNG in the runtime folder, gone at logout.
fn first_frame(file: &Path) -> Result<std::path::PathBuf> {
    let runtime = std::env::var_os("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR is not set")?;
    let folder = Path::new(&runtime).join("hyprmonk/recordings");
    fs::create_dir_all(&folder).with_context(|| format!("creating {}", folder.display()))?;
    let picture = folder
        .join(file.file_name().context("a recording has a name")?)
        .with_extension("png");
    let output = Command::new("ffmpeg")
        .args(["-loglevel", "error", "-y", "-i"])
        .arg(file)
        .args(["-frames:v", "1"])
        .arg(&picture)
        .output()
        .context("running ffmpeg")?;
    if !output.status.success() {
        bail!("ffmpeg: {}", String::from_utf8_lossy(&output.stderr).trim());
    }
    Ok(picture)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_hardware_encoder_comes_first() {
        let info = "section=video_codecs\nh264\nhevc\nh264_vulkan\nh264_software\n";
        assert_eq!(encoder(info), ["-k", "h264"]);
    }

    #[test]
    fn vulkan_stands_in_for_a_missing_nvenc() {
        let info = "section=video_codecs\nh264_software\nh264_vulkan\nhevc_vulkan\n";
        assert_eq!(encoder(info), ["-k", "h264_vulkan"]);
    }

    #[test]
    fn software_is_the_last_resort() {
        assert_eq!(
            encoder("h264_software\n"),
            ["-k", "h264", "-encoder", "cpu"]
        );
        assert_eq!(encoder(""), ["-k", "h264", "-encoder", "cpu"]);
    }
}
