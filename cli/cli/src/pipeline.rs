use std::fs;
use std::path::{Path, PathBuf};

use crate::error::CliError;
use crate::output;
use crate::preprocess;

/// 1ファイルの処理に必要な情報
pub struct FileTask {
    pub input_path: PathBuf,
    pub output_path: PathBuf,
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
    pub metadata_path: PathBuf,
    pub laps_path: PathBuf,
}

/// パイプライン: read → transform+serialize → write
pub fn process_file(task: &FileTask) -> Result<ProcessingReport, CliError> {
    let csv_content = read_csv(&task.input_path)?;
    let output = transform_and_serialize(&csv_content, &task.event_name)?;
    let written = write_files(task, &output)?;
    Ok(ProcessingReport {
        car_count: output.car_count,
        metadata_path: written.metadata_path,
        laps_path: written.laps_path,
    })
}

fn read_csv(input_path: &Path) -> Result<String, CliError> {
    fs::read_to_string(input_path).map_err(|e| CliError::ReadFile {
        path: input_path.display().to_string(),
        source: e,
    })
}

fn transform_and_serialize(
    csv_content: &str,
    event_name: &str,
) -> Result<SerializedOutput, CliError> {
    let laps_with_metadata = preprocess::parse_laps_from_csv(csv_content);
    let cars = preprocess::group_laps_by_car(laps_with_metadata.clone());
    let car_count = cars.len();
    let metadata = output::create_metadata_output(event_name, &cars);
    let laps = output::create_laps_output(&laps_with_metadata);

    let metadata_json = serde_json::to_string_pretty(&metadata).map_err(|e| {
        CliError::Serialize {
            context: "metadata",
            source: e,
        }
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

struct WrittenFiles {
    metadata_path: PathBuf,
    laps_path: PathBuf,
}

fn write_files(task: &FileTask, output: &SerializedOutput) -> Result<WrittenFiles, CliError> {
    fs::write(&task.output_path, &output.metadata_json).map_err(|e| CliError::WriteFile {
        path: task.output_path.display().to_string(),
        source: e,
    })?;

    let laps_path = {
        let stem = task
            .output_path
            .file_stem()
            .unwrap_or_default()
            .to_string_lossy();
        task.output_path
            .with_file_name(format!("{}_laps.json", stem))
    };
    fs::write(&laps_path, &output.laps_json).map_err(|e| CliError::WriteFile {
        path: laps_path.display().to_string(),
        source: e,
    })?;

    Ok(WrittenFiles {
        metadata_path: task.output_path.clone(),
        laps_path,
    })
}
