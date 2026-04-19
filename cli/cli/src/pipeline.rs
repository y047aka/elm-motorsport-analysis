use std::error::Error;
use std::fs;

use crate::output::{self, MetadataOutput, RawLap};
use crate::preprocess;

/// 1ファイルの処理に必要な情報
pub struct FileTask {
    pub input_path: String,
    pub output_path: String,
    pub event_name: String,
}

/// 変換結果
struct TransformResult {
    metadata: MetadataOutput,
    laps: Vec<RawLap>,
    car_count: usize,
}

/// パイプライン: read → transform → write
pub fn process_file(task: &FileTask) -> Result<(), Box<dyn Error>> {
    let csv_content = read_csv(&task.input_path)?;
    let result = transform(&csv_content, &task.event_name);
    println!("Read {} cars from CSV '{}'", result.car_count, task.input_path);
    write_outputs(task, &result.metadata, &result.laps)?;
    Ok(())
}

fn read_csv(input_path: &str) -> Result<String, Box<dyn Error>> {
    fs::read_to_string(input_path)
        .map_err(|e| format!("Failed to read input file '{}': {}", input_path, e).into())
}

fn transform(csv_content: &str, event_name: &str) -> TransformResult {
    let laps_with_metadata = preprocess::parse_laps_from_csv(csv_content);
    let cars = preprocess::group_laps_by_car(laps_with_metadata.clone());
    let car_count = cars.len();
    let metadata = output::create_metadata_output(event_name, &cars);
    let laps = output::create_laps_output(&laps_with_metadata);
    TransformResult {
        metadata,
        laps,
        car_count,
    }
}

fn write_outputs(
    task: &FileTask,
    metadata: &MetadataOutput,
    laps: &[RawLap],
) -> Result<(), Box<dyn Error>> {
    let metadata_json = serde_json::to_string_pretty(metadata)
        .map_err(|e| format!("Failed to serialize metadata to JSON: {e}"))?;
    let laps_json = serde_json::to_string_pretty(laps)
        .map_err(|e| format!("Failed to serialize laps to JSON: {e}"))?;

    fs::write(&task.output_path, &metadata_json)
        .map_err(|e| format!("Failed to write output file '{}': {e}", task.output_path))?;

    let laps_output_path = task.output_path.replace(".json", "_laps.json");
    fs::write(&laps_output_path, &laps_json)
        .map_err(|e| format!("Failed to write laps file '{}': {e}", laps_output_path))?;

    println!("Wrote metadata JSON to {}", task.output_path);
    println!("Wrote laps JSON to {}", laps_output_path);
    Ok(())
}
