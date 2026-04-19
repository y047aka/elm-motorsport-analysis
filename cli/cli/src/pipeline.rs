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

/// パイプライン: read → transform → write
pub fn process_file(task: &FileTask) -> Result<(), Box<dyn Error>> {
    let csv_content = read_csv(&task.input_path)?;
    let (metadata, laps) = transform(&csv_content, &task.event_name);
    println!("Read {} cars from CSV '{}'", metadata.starting_grid.len(), task.input_path);
    write_outputs(task, &metadata, &laps)?;
    Ok(())
}

fn read_csv(input_path: &str) -> Result<String, Box<dyn Error>> {
    fs::read_to_string(input_path)
        .map_err(|e| format!("Failed to read input file '{}': {}", input_path, e).into())
}

fn transform(csv_content: &str, event_name: &str) -> (MetadataOutput, Vec<RawLap>) {
    let laps_with_metadata = preprocess::parse_laps_from_csv(csv_content);
    let cars = preprocess::group_laps_by_car(laps_with_metadata.clone());
    let metadata = output::create_metadata_output(event_name, &cars);
    let laps = output::create_laps_output(&laps_with_metadata);
    (metadata, laps)
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

/// ディレクトリ内のCSVファイルを再帰的に検索
pub fn find_csv_files(dir_path: &str) -> Result<Vec<String>, Box<dyn Error>> {
    let mut csv_files = Vec::new();
    let entries = fs::read_dir(dir_path)
        .map_err(|e| format!("Failed to read directory '{}': {}", dir_path, e))?;

    for entry in entries {
        let entry = entry.map_err(|e| format!("Failed to read directory entry: {}", e))?;
        let path = entry.path();

        if path.is_dir() {
            let subdir_path = path.to_string_lossy().to_string();
            let mut subdir_files = find_csv_files(&subdir_path)?;
            csv_files.append(&mut subdir_files);
        } else if let Some(extension) = path.extension() {
            if extension == "csv" {
                csv_files.push(path.to_string_lossy().to_string());
            }
        }
    }

    Ok(csv_files)
}
