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
//! 各ステージは専用モジュールに分担されており、このモジュールはそれらを
//! 直列に繋ぐだけの薄い層。

use std::path::PathBuf;

use serde::Serialize;

use crate::FileTask;
use crate::csv_input;
use crate::error::CliError;
use crate::io;
use crate::output;
use crate::structure;
use crate::transform;

/// 処理完了の報告（呼び出し元がログに使う）
pub struct ProcessingReport {
    pub car_count: usize,
    pub metadata_path: PathBuf,
    pub laps_path: PathBuf,
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
