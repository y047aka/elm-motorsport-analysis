//! 公式 CLI API:
//! - [`FileTask`] と [`run`] でファイル処理を実行
//! - [`parse_args`] で `Vec<FileTask>` を argv から構築
//! - エラー型は [`CliError`]
//!
//! 内部のパイプラインステージ（`csv_input` / `structure` / `transform` /
//! `output` など）はプロダクションコードから直接呼ぶためのものではなく、
//! integration test 用に [`for_testing`] からアクセスする。

pub mod args;
pub mod error;
pub mod io;
pub mod pipeline;

pub(crate) mod csv_input;
pub(crate) mod domain;
pub(crate) mod output;
pub(crate) mod structure;
pub(crate) mod transform;

pub use args::parse_args;
pub use error::CliError;

/// Integration test 用の内部構造アクセス。プロダクションコードからは使用しない。
///
/// パイプラインの各ステージを個別に呼び出したり、中間表現 [`LapRecord`]
/// を直接観察したりするためのエントリポイント。
pub mod for_testing {
    pub use crate::domain::LapRecord;
    pub use crate::output::{MetadataOutput, create_laps_output, create_metadata_output};
    pub use crate::transform::group_laps_by_car;

    /// CSV テキストからパース + 構造化の 2 ステージを束ねて [`LapRecord`] を得る。
    pub fn parse_and_structure(csv: &str) -> Vec<LapRecord> {
        crate::structure::structure(crate::csv_input::parse(csv))
    }
}

use std::path::{Path, PathBuf};

use pipeline::ProcessingReport;

/// 1ファイルの処理に必要な情報
pub struct FileTask {
    input_path: PathBuf,
    output_path: PathBuf,
    event_name: String,
}

impl FileTask {
    /// 入力ファイルパスから FileTask を生成する。
    /// output_override が None の場合、入力ファイルの拡張子を .json に置換したパスを使う。
    pub fn new(input_path: PathBuf, output_override: Option<PathBuf>) -> Self {
        let stem = input_path
            .file_stem()
            .unwrap_or_else(|| std::ffi::OsStr::new("output"))
            .to_string_lossy();

        let output_path = output_override
            .unwrap_or_else(|| input_path.with_extension("json"));
        let event_name = stem.to_string();

        Self {
            input_path,
            output_path,
            event_name,
        }
    }

    pub fn input_path(&self) -> &Path {
        &self.input_path
    }

    pub fn output_path(&self) -> &Path {
        &self.output_path
    }

    pub fn event_name(&self) -> &str {
        &self.event_name
    }

    pub fn laps_path(&self) -> PathBuf {
        let stem = self
            .output_path
            .file_stem()
            .unwrap_or_default()
            .to_string_lossy();
        self.output_path
            .with_file_name(format!("{}_laps.json", stem))
    }
}

pub struct FileOutcome {
    pub input_path: PathBuf,
    pub result: Result<ProcessingReport, CliError>,
}

pub fn run(tasks: Vec<FileTask>) -> impl Iterator<Item = FileOutcome> {
    tasks.into_iter().map(|task| {
        let input_path = task.input_path().to_path_buf();
        let result = pipeline::process_file(&task);
        FileOutcome { input_path, result }
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn file_task_default_output() {
        let task = FileTask::new(PathBuf::from("input.csv"), None);
        assert_eq!(task.output_path(), Path::new("input.json"));
        assert_eq!(task.event_name(), "input");
    }

    #[test]
    fn file_task_with_output_override() {
        let task = FileTask::new(PathBuf::from("input.csv"), Some(PathBuf::from("custom.json")));
        assert_eq!(task.output_path(), Path::new("custom.json"));
        assert_eq!(task.event_name(), "input");
    }
}
