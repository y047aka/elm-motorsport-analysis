use std::error::Error;
use std::fs;

use crate::output;
use crate::preprocess;

/// 1ファイルの処理に必要な情報
pub struct FileTask {
    pub input_path: String,
    pub output_path: String,
    pub event_name: String,
}

/// 変換・直列化の結果（純粋な変換の出力）
struct SerializedOutput {
    metadata_json: String,
    laps_json: String,
    car_count: usize,
}

/// 処理完了の報告（呼び出し元がログに使う）
pub struct ProcessingReport {
    pub car_count: usize,
    pub metadata_path: String,
    pub laps_path: String,
}

/// パイプライン: read → transform+serialize → write
pub fn process_file(task: &FileTask) -> Result<ProcessingReport, Box<dyn Error>> {
    let csv_content = read_csv(&task.input_path)?;
    let output = transform_and_serialize(&csv_content, &task.event_name)?;
    let report = write_files(task, &output)?;
    Ok(ProcessingReport {
        car_count: output.car_count,
        ..report
    })
}

fn read_csv(input_path: &str) -> Result<String, Box<dyn Error>> {
    fs::read_to_string(input_path)
        .map_err(|e| format!("Failed to read input file '{}': {}", input_path, e).into())
}

fn transform_and_serialize(
    csv_content: &str,
    event_name: &str,
) -> Result<SerializedOutput, Box<dyn Error>> {
    let laps_with_metadata = preprocess::parse_laps_from_csv(csv_content);
    let cars = preprocess::group_laps_by_car(laps_with_metadata.clone());
    let car_count = cars.len();
    let metadata = output::create_metadata_output(event_name, &cars);
    let laps = output::create_laps_output(&laps_with_metadata);

    let metadata_json = serde_json::to_string_pretty(&metadata)
        .map_err(|e| format!("Failed to serialize metadata to JSON: {e}"))?;
    let laps_json = serde_json::to_string_pretty(&laps)
        .map_err(|e| format!("Failed to serialize laps to JSON: {e}"))?;

    Ok(SerializedOutput {
        metadata_json,
        laps_json,
        car_count,
    })
}

fn write_files(
    task: &FileTask,
    output: &SerializedOutput,
) -> Result<ProcessingReport, Box<dyn Error>> {
    fs::write(&task.output_path, &output.metadata_json)
        .map_err(|e| format!("Failed to write output file '{}': {e}", task.output_path))?;

    let laps_path = task.output_path.replace(".json", "_laps.json");
    fs::write(&laps_path, &output.laps_json)
        .map_err(|e| format!("Failed to write laps file '{}': {e}", laps_path))?;

    Ok(ProcessingReport {
        car_count: output.car_count,
        metadata_path: task.output_path.clone(),
        laps_path,
    })
}
