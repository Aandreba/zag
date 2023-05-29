use clap::Parser;
use color_eyre::Report;
use std::{
    io::{BufReader, BufWriter},
    path::PathBuf,
};
use url::Url;

use crate::parse::{ZagDep, ZagFile};

/// Initializes Zag to be able to be used
#[derive(Parser, Debug)]
pub struct Add {
    repo: Url,
    version: String,
    entry: Option<PathBuf>,
    name: Option<String>,
    target_path: Option<PathBuf>,
    target_entry: Option<PathBuf>,
}

impl Add {
    pub fn execute(self) -> color_eyre::Result<()> {
        let cwd = match self.target_path {
            Some(path) => path,
            None => std::env::current_dir()?,
        };

        let cwd_entry: PathBuf = match self.target_entry {
            Some(path) => cwd.join(path),
            None => cwd.join("zag.json"),
        };

        let name = match self.name {
            Some(name) => name,
            None => self
                .repo
                .path_segments()
                .ok_or_else(|| Report::msg("'repo' cannot be a base URL"))?
                .last()
                .ok_or_else(|| Report::msg("could not find name from 'repo'"))?
                .to_owned(),
        };

        let mut file: std::fs::File = std::fs::File::options()
            .read(true)
            .append(true)
            .open(cwd_entry)?;
        let mut values: ZagFile = serde_json::from_reader(BufReader::new(&mut file))?;

        match values.deps.entry(name) {
            std::collections::hash_map::Entry::Occupied(_) => todo!(),
            std::collections::hash_map::Entry::Vacant(entry) => {
                entry.insert(ZagDep {
                    repo: self.repo.to_string(),
                    version: self.version,
                    entry: self.entry.map(|x| x.display().to_string()),
                });
            }
        }

        file.set_len(0)?;
        serde_json::to_writer_pretty(BufWriter::new(file), &values)?;

        Ok(())
    }
}
