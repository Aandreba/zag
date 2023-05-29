use std::collections::HashMap;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ZagFile {
    pub dir: Option<String>,
    pub deps: HashMap<String, ZagDep>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ZagDep {
    pub repo: String,
    pub version: String,
    pub entry: Option<String>,
}
