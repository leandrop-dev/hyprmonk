//! `hyprmonk`: command-line helpers for the hyprmonk desktop.

mod battery;
mod hidraw;
mod screenshot;
mod steelseries;

use std::io::{self, Write};
use std::process::ExitCode;

use anyhow::Result;

const USAGE: &str = "\
usage: hyprmonk <command>

commands:
  battery [--json]                       charge of devices UPower cannot see (SteelSeries Rival 3 Wireless)
  screenshot region|window|screen [--copy]
                                         take a screenshot: annotate and save it, or copy it
  help                                   show this text
";

fn main() -> ExitCode {
    // Lossy, not `args()`, which panics on an argument that is not UTF-8:
    // such an argument matches no command and gets the usage text.
    let args: Vec<String> = std::env::args_os()
        .skip(1)
        .map(|arg| arg.to_string_lossy().into_owned())
        .collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    match run(&args) {
        Ok(code) => code,
        Err(err) => {
            eprintln!("hyprmonk: {err:#}");
            ExitCode::FAILURE
        }
    }
}

fn run(args: &[&str]) -> Result<ExitCode> {
    match args {
        ["battery"] => print_battery(battery::Format::Text),
        ["battery", "--json"] => print_battery(battery::Format::Json),
        ["screenshot", area] => take_screenshot(area, screenshot::Target::File),
        ["screenshot", area, "--copy"] => take_screenshot(area, screenshot::Target::Clipboard),
        ["help" | "--help" | "-h"] => {
            print!("{USAGE}");
            Ok(ExitCode::SUCCESS)
        }
        _ => {
            eprint!("{USAGE}");
            Ok(ExitCode::from(2))
        }
    }
}

fn print_battery(format: battery::Format) -> Result<ExitCode> {
    let readings = battery::read_all()?;
    io::stdout().write_all(battery::render(&readings, format).as_bytes())?;
    Ok(ExitCode::SUCCESS)
}

fn take_screenshot(area: &str, target: screenshot::Target) -> Result<ExitCode> {
    let Ok(area) = area.parse() else {
        eprint!("{USAGE}");
        return Ok(ExitCode::from(2));
    };
    if let Err(err) = screenshot::take(area, target) {
        screenshot::report(&err);
        return Err(err);
    }
    Ok(ExitCode::SUCCESS)
}
