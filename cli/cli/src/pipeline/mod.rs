//! ワークフローのオーケストレーション。
//!
//! 1ファイルを処理する際の流れ:
//!
//! ```text
//! read_csv ─▶ parse ─▶ structure ─▶ transform ─▶ serialize ─▶ write_json
//!   (io)    (csv_input) (structure)   (transform+           (io)
//!                                      output)
//! ```
//!
//! このモジュールは:
//! - **タスクの表現**: [`FileTask`] / [`FileOutcome`] / [`ProcessingReport`]
//! - **タスクの実行**: [`run`]（複数タスク）／ [`process_file`]（1タスク）
//! - **ステージの直列合成**: 6段階の合成ロジック
//!
//! を担う。各ステージは専用サブモジュール（[`io`] / [`csv_input`] /
//! [`structure`] / [`transform`] / [`output`]）に分担されており、ここでは
//! それらを直列に繋ぐ。

pub(crate) mod csv_input;
pub(crate) mod io;
pub(crate) mod output;
pub(crate) mod structure;
pub(crate) mod transform;

use std::path::{Path, PathBuf};

use serde::Serialize;

use crate::error::CliError;

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

        let output_path = output_override.unwrap_or_else(|| input_path.with_extension("json"));
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

/// 1ファイル処理の結果（成功／失敗のいずれでも返る）。
pub struct FileOutcome {
    pub input_path: PathBuf,
    pub result: Result<ProcessingReport, CliError>,
}

/// 処理完了の報告（呼び出し元がログに使う）
pub struct ProcessingReport {
    pub car_count: usize,
    pub metadata_path: PathBuf,
    pub laps_path: PathBuf,
}

/// 複数のタスクを実行し、各ファイルの処理結果を [`FileOutcome`] として順に返す。
pub fn run(tasks: Vec<FileTask>) -> impl Iterator<Item = FileOutcome> {
    tasks.into_iter().map(|task| {
        let input_path = task.input_path().to_path_buf();
        let result = process_file(&task);
        FileOutcome { input_path, result }
    })
}

/// 1ファイル分のパイプライン: read → parse → structure → transform → serialize → write
pub fn process_file(task: &FileTask) -> Result<ProcessingReport, CliError> {
    // Stage 1: read
    let csv_content = io::read_csv(task.input_path())?;

    // Stage 2: parse (CSV テキスト → CsvRow のリスト、字句的な読み取り)
    let rows = csv_input::parse(&csv_content);

    // Stage 3: structure (CsvRow → LapRecord、意味論的な変換)
    let records = structure::structure(rows);

    // Stage 4: transform (LapRecord → 出力可能な中間表現へ射影)
    //
    // laps は LapRecord から直接構築する。Car には集約済みの情報しか残らないため、
    // ラップ単位の CSV 由来情報を transform 前に退避する必要がある。
    let raw_laps = output::create_laps_output(&records);
    let cars = transform::group_laps_by_car(records);
    let metadata = output::create_metadata_output(task.event_name(), &cars);
    let car_count = cars.len();

    // Stage 5: serialize (中間表現 → JSON 文字列、純粋な文字列変換)
    let metadata_json = to_json_pretty(&metadata, "metadata")?;
    let laps_json = to_json_pretty(&raw_laps, "laps")?;

    // Stage 6: write
    let metadata_path = task.output_path().to_path_buf();
    let laps_path = task.laps_path();
    io::write_json(&metadata_path, &metadata_json)?;
    io::write_json(&laps_path, &laps_json)?;

    Ok(ProcessingReport {
        car_count,
        metadata_path,
        laps_path,
    })
}

fn to_json_pretty<T: Serialize>(value: &T, context: &'static str) -> Result<String, CliError> {
    serde_json::to_string_pretty(value).map_err(|source| CliError::Serialize { context, source })
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
