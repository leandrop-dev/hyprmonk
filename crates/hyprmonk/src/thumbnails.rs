//! `hyprmonk thumbnails`: small copies of the wallpapers, for the picker.
//!
//! Drawing a tile from the picture itself decodes all of it, up to 24 MB of
//! PNG, one at a time. A thumbnail is a JPEG of a few tens of KB. They are
//! kept in `~/.cache/hyprmonk/wallpapers` under the picture's name, made again
//! when the picture is newer and removed when it is gone.

use std::ffi::OsString;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::Mutex;
use std::thread;

use anyhow::{Context, Result};

/// Cropped to the tile's 16:9, at about twice its size.
const SIZE: &str = "480x270";

const EXTENSIONS: [&str; 5] = ["jpg", "jpeg", "png", "webp", "bmp"];

/// Brings the thumbnails up to date with `folder`.
pub fn refresh(folder: &Path) -> Result<()> {
    let cache = cache_dir()?;
    fs::create_dir_all(&cache).with_context(|| format!("creating {}", cache.display()))?;
    let pictures = pictures(folder).with_context(|| format!("reading {}", folder.display()))?;
    prune(&cache, &pictures)?;

    let stale: Vec<_> = pictures
        .iter()
        .filter(|name| is_stale(folder, &cache, name))
        .collect();
    let queue = Mutex::new(stale.into_iter());
    let next = || {
        queue
            .lock()
            .expect("no thread panics holding this lock")
            .next()
    };
    let workers = thread::available_parallelism().map_or(1, |cores| cores.get().div_ceil(2));
    thread::scope(|scope| {
        for _ in 0..workers {
            scope.spawn(|| {
                while let Some(name) = next() {
                    if let Err(err) = make(&folder.join(name), &cache, name) {
                        eprintln!("hyprmonk: {}: {err:#}", folder.join(name).display());
                    }
                }
            });
        }
    });
    Ok(())
}

fn cache_dir() -> Result<PathBuf> {
    let base = std::env::var_os("XDG_CACHE_HOME")
        .filter(|dir| !dir.is_empty())
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| Path::new(&home).join(".cache")))
        .context("HOME is not set")?;
    Ok(base.join("hyprmonk/wallpapers"))
}

/// The file names of the pictures in `folder`.
fn pictures(folder: &Path) -> io::Result<Vec<OsString>> {
    let mut names = Vec::new();
    for entry in fs::read_dir(folder)? {
        let path = entry?.path();
        if is_picture(&path) {
            names.extend(path.file_name().map(OsString::from));
        }
    }
    Ok(names)
}

fn is_picture(path: &Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| EXTENSIONS.contains(&extension.to_ascii_lowercase().as_str()))
}

/// `a.png`'s thumbnail is `a.png.jpg`: the picture's whole name keeps `a.png`
/// and `a.jpg` apart, and the shell can tell it from the path alone.
fn thumbnail_name(picture: &OsString) -> OsString {
    let mut name = picture.clone();
    name.push(".jpg");
    name
}

/// Removes the thumbnails of pictures that are gone.
fn prune(cache: &Path, pictures: &[OsString]) -> Result<()> {
    let wanted: Vec<OsString> = pictures.iter().map(thumbnail_name).collect();
    for entry in fs::read_dir(cache).with_context(|| format!("reading {}", cache.display()))? {
        let entry = entry?;
        if !wanted.contains(&entry.file_name()) {
            fs::remove_file(entry.path())
                .with_context(|| format!("removing {}", entry.path().display()))?;
        }
    }
    Ok(())
}

fn is_stale(folder: &Path, cache: &Path, name: &OsString) -> bool {
    let modified = |path: PathBuf| fs::metadata(path).and_then(|meta| meta.modified());
    match (
        modified(folder.join(name)),
        modified(cache.join(thumbnail_name(name))),
    ) {
        (Ok(picture), Ok(thumbnail)) => thumbnail < picture,
        _ => true,
    }
}

/// Written beside its place and moved in, so the picker never reads half of it.
fn make(picture: &Path, cache: &Path, name: &OsString) -> Result<()> {
    let target = cache.join(thumbnail_name(name));
    let partial = target.with_extension("partial.jpg");
    let mut output = OsString::from(&partial);
    output.push("[Q=82,strip]");
    let done = Command::new("vipsthumbnail")
        .arg(picture)
        .args(["--size", SIZE, "--smartcrop", "centre", "--output"])
        .arg(output)
        .stdout(Stdio::null())
        .output()
        .context("running vipsthumbnail")?;
    if !done.status.success() {
        let _ = fs::remove_file(&partial);
        anyhow::bail!(
            "vipsthumbnail: {}",
            String::from_utf8_lossy(&done.stderr).trim()
        );
    }
    fs::rename(&partial, &target).with_context(|| format!("moving to {}", target.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn knows_pictures_by_extension() {
        assert!(is_picture(Path::new("/w/a.JPG")));
        assert!(is_picture(Path::new("/w/a.webp")));
        assert!(!is_picture(Path::new("/w/a.txt")));
        assert!(!is_picture(Path::new("/w/a")));
    }

    #[test]
    fn a_thumbnail_is_named_after_the_whole_picture() {
        assert_eq!(
            thumbnail_name(&OsString::from("a.png")),
            OsString::from("a.png.jpg")
        );
    }
}
