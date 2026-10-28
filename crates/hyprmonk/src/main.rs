//! `hyprmonk`: command-line helpers for the hyprmonk desktop.

mod battery;
mod hidraw;
mod steelseries;

use std::io::{self, Write};
use std::process::ExitCode;

use anyhow::Result;

const USAGE: &str = "\
usage: hyprmonk <command>

commands:
  battery [--json]   charge of devices UPower cannot see (SteelSeries Rival 3 Wireless)
  help               show this text
";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
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
