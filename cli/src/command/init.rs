use clap::Parser;
use std::{
    io::{Seek, Write},
    path::PathBuf,
    process::Stdio,
};

pub const GIT_URL: &str = "https://github.com/Aandreba/zag";

/// Initializes Zag to be able to be used
#[derive(Parser, Debug)]
pub struct Init {
    path: Option<PathBuf>,
}

impl Init {
    pub fn execute(self) -> color_eyre::Result<()> {
        let cwd = match self.path {
            Some(path) => path,
            None => std::env::current_dir()?,
        };

        // add zag
        std::process::Command::new("git")
            .args(["submodule", "add", GIT_URL])
            .stdout(Stdio::null())
            .current_dir(&cwd)
            .status()?
            .exit_ok()?;

        // add library to build file
        let mut build_file = std::fs::File::options()
            .append(true)
            .open(cwd.join("build.zig"))?;
        build_file.seek(std::io::SeekFrom::Start(0))?;
        build_file.write_all(br#"const zag = @import("zag/main.zig");\n"#)?;

        todo!()
    }
}
