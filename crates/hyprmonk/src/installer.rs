//! The repo's `install.sh`, run from wherever the repo was cloned: found
//! through `~/.config/hypr`, which `install.sh link` made a link into it.

use std::env;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{Context, Result, bail};

/// Replaces this process with `install.sh args...`, so the menu gets the
/// terminal. Returns only if that fails.
pub fn exec(args: &[&str]) -> Result<()> {
    let script = repo()?.join("install.sh");
    let err = Command::new(&script).args(args).exec();
    Err(err).with_context(|| format!("running {}", script.display()))
}

/// `$HYPRMONK_DIR`, else the repo `~/.config/hypr` links into.
fn repo() -> Result<PathBuf> {
    if let Some(dir) = env::var_os("HYPRMONK_DIR") {
        return Ok(PathBuf::from(dir));
    }
    let home = env::var_os("HOME").context("HOME is not set")?;
    let link = Path::new(&home).join(".config/hypr");
    let Ok(target) = link.read_link() else {
        bail!(
            "{} is not a link into the repo (install.sh link makes it); set HYPRMONK_DIR to the repo",
            link.display()
        );
    };
    match from_config_link(&target) {
        Some(repo) if repo.join("install.sh").is_file() => Ok(repo),
        _ => bail!(
            "{} links to {}, not to a repo's config/hypr; set HYPRMONK_DIR to the repo",
            link.display(),
            target.display()
        ),
    }
}

/// `REPO/config/hypr` -> `REPO`.
fn from_config_link(target: &Path) -> Option<PathBuf> {
    if !target.ends_with("config/hypr") {
        return None;
    }
    target.parent()?.parent().map(Path::to_path_buf)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn repo_from_the_link() {
        assert_eq!(
            from_config_link(Path::new("/home/me/.local/share/hyprmonk/config/hypr")),
            Some(PathBuf::from("/home/me/.local/share/hyprmonk"))
        );
    }

    #[test]
    fn a_link_elsewhere_is_no_repo() {
        assert_eq!(from_config_link(Path::new("/home/me/dotfiles/hypr")), None);
    }
}
