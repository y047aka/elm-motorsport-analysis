//! Filesystem boundary. Side effects are confined to this module.

use std::fs;
use std::path::Path;

use crate::error::CliError;

pub fn read_csv(path: &Path) -> Result<String, CliError> {
    fs::read_to_string(path).map_err(|source| CliError::ReadFile {
        path: path.display().to_string(),
        source,
    })
}

pub fn write_json(path: &Path, content: &str) -> Result<(), CliError> {
    fs::write(path, content).map_err(|source| CliError::WriteFile {
        path: path.display().to_string(),
        source,
    })
}
