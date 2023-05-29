#![allow(clippy::needless_return)]
#![feature(exit_status_error)]

use clap::{Parser, Subcommand};
use command::{add::Add, init::Init};

pub mod command;
pub mod parse;

/// Simple program to greet a person
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand, Debug)]
enum Command {
    Init(Init),
    Add(Add),
}

fn main() -> color_eyre::Result<()> {
    _ = color_eyre::install();
    let cli = Cli::parse();
    return Ok(());
}
