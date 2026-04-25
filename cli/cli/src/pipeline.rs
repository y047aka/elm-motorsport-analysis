//! ワークフローのオーケストレーション。
//!
//! 1ファイルを処理する際の流れ:
//!
//! ```text
//! read_csv ──▶ parse_laps_from_csv ──▶ group_laps_by_car ──▶ serialize ──▶ write_json
//! ```
//!
//! 各ステージは [`io`] / [`csv_input`] / [`transform`] / [`output`] に分担されており、
//! このモジュールはそれらを直列に繋ぐだけ。

use std::path::PathBuf;

use crate::FileTask;
use crate::csv_input::{self, LapWithMetadata};
use crate::error::CliError;
use crate::io;
use crate::output;
use crate::transform;

/// 処理完了の報告（呼び出し元がログに使う）
pub struct ProcessingReport {
    pub car_count: usize,
    pub metadata_path: PathBuf,
    pub laps_path: PathBuf,
}

/// 1ファイル分のパイプライン: read → parse → transform → serialize → write
pub fn process_file(task: &FileTask) -> Result<ProcessingReport, CliError> {
    // Stage 1: read
    let csv_content = io::read_csv(task.input_path())?;

    // Stage 2: parse (CSV → LapWithMetadata のリスト)
    let laps_with_metadata = csv_input::parse_laps_from_csv(&csv_content);

    // Stage 3: serialize laps & transform (LapWithMetadata → Car のリスト)
    //
    // laps は LapWithMetadata から直接構築する。Car には集約済みの情報しか入らないため、
    // ラップ単体の CSV 由来情報は transform 前に退避する必要がある。
    let (metadata_json, laps_json, car_count) =
        serialize(task.event_name(), &laps_with_metadata)?;

    // Stage 4: write
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

/// LapWithMetadata のリストから metadata/laps の両 JSON を組み立てる（副作用なし）。
fn serialize(
    event_name: &str,
    laps_with_metadata: &[LapWithMetadata],
) -> Result<(String, String, usize), CliError> {
    let laps = output::create_laps_output(laps_with_metadata);
    let cars = transform::group_laps_by_car(laps_with_metadata.to_vec());
    let car_count = cars.len();
    let metadata = output::create_metadata_output(event_name, &cars);

    let metadata_json =
        serde_json::to_string_pretty(&metadata).map_err(|e| CliError::Serialize {
            context: "metadata",
            source: e,
        })?;
    let laps_json = serde_json::to_string_pretty(&laps).map_err(|e| CliError::Serialize {
        context: "laps",
        source: e,
    })?;

    Ok((metadata_json, laps_json, car_count))
}
