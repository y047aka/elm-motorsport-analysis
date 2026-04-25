//! ファイル入出力の境界。副作用を持つ操作はこのモジュールに集約する。

use std::fs;
use std::path::Path;

use crate::error::CliError;

/// CSV ファイルを文字列として読み込む。
pub fn read_csv(path: &Path) -> Result<String, CliError> {
    fs::read_to_string(path).map_err(|source| CliError::ReadFile {
        path: path.display().to_string(),
        source,
    })
}

/// JSON 文字列をファイルに書き出す。
pub fn write_json(path: &Path, content: &str) -> Result<(), CliError> {
    fs::write(path, content).map_err(|source| CliError::WriteFile {
        path: path.display().to_string(),
        source,
    })
}
