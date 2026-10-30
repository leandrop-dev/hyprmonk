//! `hyprmonk record`: a screen or a region picked with slurp to the Videos
//! folder, by GPU Screen Recorder, with the system's sound, the microphone,
//! both or neither. `hyprmonk replay` keeps the last minute of a screen in
//! memory instead. The shell runs them and signals them, which is why this
//! becomes the recorder rather than waiting for it; `hyprmonk recording-saved`
//! then says where it went.

use std::fs;
use std::io::{self, Write as _};
use std::os::unix::process::CommandExt as _;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result, bail};

use crate::screenshot;

const RECORDER: &str = "gpu-screen-recorder";

/// The quick actions card folds away before the picker covers the screen.
const CARD_GONE: Duration = Duration::from_millis(250);

/// How much a replay keeps.
const REPLAY_SECONDS: &str = "60";

/// What is heard in a recording.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Audio {
    Silent,
    /// What the system plays.
    Sound,
    /// The default microphone.
    Microphone,
    /// Both, mixed into one track, so any player plays them together.
    Both,
}

impl Audio {
    /// From `record`'s flags, in any order; `None` for anything else.
    #[must_use]
    pub fn from_flags(flags: &[&str]) -> Option<Self> {
        match flags {
            [] => Some(Audio::Silent),
            ["--sound"] => Some(Audio::Sound),
            ["--microphone"] => Some(Audio::Microphone),
            ["--sound", "--microphone"] | ["--microphone", "--sound"] => Some(Audio::Both),
            _ => None,
        }
    }

    /// The recorder's `-a` source, if there is one.
    fn source(self) -> Option<&'static str> {
        match self {
            Audio::Silent => None,
            Audio::Sound => Some("default_output"),
            Audio::Microphone => Some("default_input"),
            Audio::Both => Some("default_output|default_input"),
        }
    }
}

/// Records `area`, a monitor's name or `region` to pick one. Prints the file
/// it will write, then becomes the recorder. Returns only if that fails, or at
/// once with nothing printed if the pick is cancelled.
///
/// # Errors
///
/// Fails when the picker, the folder or the recorder fails.
pub fn start(area: &str, audio: Audio) -> Result<()> {
    let target = if area == "region" {
        thread::sleep(CARD_GONE);
        let Some(region) = screenshot::select(&["-d", "-f", "%wx%h+%x+%y"], "")? else {
            return Ok(());
        };
        region
    } else {
        area.to_owned()
    };

    let stamp = screenshot::timestamp(screenshot::FILE_TIME)?;
    let path = folder()?.join(format!("Recording_{stamp}.mp4"));
    let mut recorder = recorder(&target, audio)?;

    let mut stdout = io::stdout();
    writeln!(stdout, "{}", path.display())?;
    stdout.flush()?;

    let err = recorder.arg("-o").arg(&path).exec();
    Err(err).with_context(|| format!("running {RECORDER}"))
}

/// Keeps the last minute of `monitor` in memory: becomes the recorder, which
/// writes it to the folder on SIGUSR1, printing the file, and drops it on
/// SIGINT.
///
/// # Errors
///
/// Fails when the folder or the recorder fails.
pub fn replay(monitor: &str, audio: Audio) -> Result<()> {
    let err = recorder(monitor, audio)?
        .args(["-r", REPLAY_SECONDS, "-c", "mp4", "-o"])
        .arg(folder()?)
        .exec();
    Err(err).with_context(|| format!("running {RECORDER}"))
}

/// Where recordings go, made if it is not there.
fn folder() -> Result<PathBuf> {
    let folder = screenshot::user_folder("VIDEOS", "Videos").join("Recordings");
    fs::create_dir_all(&folder).with_context(|| format!("creating {}", folder.display()))?;
    Ok(folder)
}

/// The recorder for `target`, up to where a recording and a replay differ.
fn recorder(target: &str, audio: Audio) -> Result<Command> {
    let info = Command::new(RECORDER)
        .arg("--info")
        .output()
        .with_context(|| format!("running {RECORDER}"))?;
    let info = String::from_utf8_lossy(&info.stdout);

    let mut recorder = Command::new(RECORDER);
    recorder.args(["-w", target, "-f", "60", "-v", "no"]);
    if let Some(source) = audio.source() {
        recorder.args(["-a", source]);
    }
    recorder.args(encoder(&info));
    Ok(recorder)
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
fn first_frame(file: &Path) -> Result<PathBuf> {
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
    fn flags_say_what_is_heard() {
        assert_eq!(Audio::from_flags(&[]), Some(Audio::Silent));
        assert_eq!(Audio::from_flags(&["--sound"]), Some(Audio::Sound));
        assert_eq!(
            Audio::from_flags(&["--microphone"]),
            Some(Audio::Microphone)
        );
        assert_eq!(
            Audio::from_flags(&["--microphone", "--sound"]),
            Some(Audio::Both)
        );
        assert_eq!(Audio::from_flags(&["--loud"]), None);
    }

    #[test]
    fn both_are_one_source() {
        assert_eq!(Audio::Silent.source(), None);
        assert_eq!(Audio::Both.source(), Some("default_output|default_input"));
    }

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
