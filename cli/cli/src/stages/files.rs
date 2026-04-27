//! Filesystem boundary. Side effects are confined to this module.

use std::fs;
use std::path::Path;

use crate::error::FileError;

pub fn read_csv(path: &Path) -> Result<String, FileError> {
    fs::read_to_string(path).map_err(|source| FileError::ReadFile {
        path: path.to_path_buf(),
        source,
    })
}

pub fn write_json(path: &Path, content: &str) -> Result<(), FileError> {
    fs::write(path, content).map_err(|source| FileError::WriteFile {
        path: path.to_path_buf(),
        source,
    })
}
