//! Race timing CSV → analysis JSON コンバータ（CLI library）。
//!
//! # 公開 API
//! - `run`: argv を受けてプログラム全体を実行する（TRPL スタイル）
//! - `RunSummary`: 実行後のサマリ（成功・失敗件数）
//! - `FileTask` / `FileOutcome` / `ProcessingReport`: タスク単位の型
//! - `parse_args` / `CliError`
//!
//! # 1ファイルの処理フロー
//!
//! ```text
//! read_csv ─▶ parse ─▶ structure ─▶ transform ─▶ serialize ─▶ write_json
//!   (io)    (csv_input) (structure)   (transform+              (io)
//!                                      output)
//! ```
//!
//! 各ステージの実装は [`stages`] モジュール以下。このファイルは `FileTask`
//! の実行と 6 段階の合成（[`process_file`] 内）を担う。

pub mod args;
pub mod error;

pub(crate) mod domain;
pub(crate) mod stages;

pub use args::parse_args;
pub use error::CliError;

use std::path::{Path, PathBuf};

use serde::Serialize;

// ================================================================
// Public API types
// ================================================================

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

/// 1ファイル処理が成功したときの報告。
pub struct ProcessingReport {
    pub car_count: usize,
    pub metadata_path: PathBuf,
    pub laps_path: PathBuf,
}

/// プログラム全体の実行サマリ。
#[derive(Debug, Default)]
pub struct RunSummary {
    pub processed: u32,
    pub errors: u32,
}

// ================================================================
// Program entry point
// ================================================================

/// argv を受けてプログラム全体を実行する。
///
/// - 引数のパースに失敗した場合は [`Err`]（setup エラー）
/// - 各ファイル処理は内部で完結し、成否は [`RunSummary`] に集約される
///   - 個別ファイルの成功／失敗は `log` クレート経由で出力される
pub fn run(args: impl Iterator<Item = String>) -> Result<RunSummary, CliError> {
    let tasks = parse_args(args)?;
    let mut summary = RunSummary::default();

    for task in tasks {
        let outcome = execute_task(task);
        match &outcome.result {
            Ok(report) => {
                log::info!(
                    "Read {} cars from CSV '{}'",
                    report.car_count,
                    outcome.input_path.display()
                );
                log::info!("Wrote metadata JSON to {}", report.metadata_path.display());
                log::info!("Wrote laps JSON to {}", report.laps_path.display());
                summary.processed += 1;
            }
            Err(error) => {
                log::error!(
                    "Error processing '{}': {}",
                    outcome.input_path.display(),
                    error
                );
                summary.errors += 1;
            }
        }
    }

    log::info!(
        "Processing completed: {} processed, {} errors",
        summary.processed,
        summary.errors
    );
    Ok(summary)
}

// ================================================================
// Per-file execution
// ================================================================

fn execute_task(task: FileTask) -> FileOutcome {
    let input_path = task.input_path().to_path_buf();
    let result = process_file(&task);
    FileOutcome { input_path, result }
}

/// 1ファイル分のパイプライン: read → parse → structure → transform → serialize → write
fn process_file(task: &FileTask) -> Result<ProcessingReport, CliError> {
    use stages::{csv_input, io, output, structure, transform};

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

// ================================================================
// Test-only hooks
// ================================================================

/// Integration test 用の内部構造アクセス。プロダクションコードからは使用しない。
pub mod for_testing {
    pub use crate::domain::LapRecord;
    pub use crate::stages::output::{MetadataOutput, create_laps_output, create_metadata_output};
    pub use crate::stages::transform::group_laps_by_car;

    /// CSV テキストからパース + 構造化の 2 ステージを束ねて [`LapRecord`] を得る。
    pub fn parse_and_structure(csv: &str) -> Vec<LapRecord> {
        crate::stages::structure::structure(crate::stages::csv_input::parse(csv))
    }
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
