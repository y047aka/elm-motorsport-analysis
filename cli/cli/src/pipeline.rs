//! ワークフローのオーケストレーション。
//!
//! 1ファイルを処理する際の流れ:
//!
//! ```text
//! read_csv ─▶ parse ─▶ structure ─▶ group_laps_by_car ─▶ serialize ─▶ write_json
//!   (io)    (csv_input) (structure)    (transform)         (output)      (io)
//! ```
//!
//! 各ステージは専用モジュールに分担されており、このモジュールはそれらを
//! 直列に繋ぐだけの薄い層。

use std::path::PathBuf;

use crate::FileTask;
use crate::csv_input;
use crate::domain::LapRecord;
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

/// シリアライズステージの成果物（純粋な文字列出力）。
struct SerializedOutput {
    metadata_json: String,
    laps_json: String,
    car_count: usize,
}

/// 1ファイル分のパイプライン: read → parse → structure → transform → serialize → write
pub fn process_file(task: &FileTask) -> Result<ProcessingReport, CliError> {
    // Stage 1: read
    let csv_content = io::read_csv(task.input_path())?;

    // Stage 2: parse (CSV テキスト → CsvRow のリスト、字句的な読み取り)
    let rows = csv_input::parse(&csv_content);

    // Stage 3: structure (CsvRow → LapRecord、意味論的な変換)
    let records = structure::structure(rows);

    // Stage 4: serialize (transform + JSON 化)
    //
    // laps は LapRecord から直接構築する。Car には集約済みの情報しか残らないため、
    // ラップ単位の CSV 由来情報を transform 前に退避する必要がある。
    let output = serialize(task.event_name(), records)?;

    // Stage 5: write
    let metadata_path = task.output_path().to_path_buf();
    let laps_path = task.laps_path();
    io::write_json(&metadata_path, &output.metadata_json)?;
    io::write_json(&laps_path, &output.laps_json)?;

    Ok(ProcessingReport {
        car_count: output.car_count,
        metadata_path,
        laps_path,
    })
}

/// LapRecord のリストから metadata / laps の両 JSON を組み立てる（副作用なし）。
fn serialize(event_name: &str, records: Vec<LapRecord>) -> Result<SerializedOutput, CliError> {
    let laps = output::create_laps_output(&records);
    let cars = transform::group_laps_by_car(records);
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

    Ok(SerializedOutput {
        metadata_json,
        laps_json,
        car_count,
    })
}
