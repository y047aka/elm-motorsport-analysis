use std::fs;
use std::path::{Path, PathBuf};

use crate::error::CliError;
use crate::output;
use crate::preprocess;

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
    let csv_content = read_csv(task.input_path())?;
    let output = transform_and_serialize(&csv_content, task.event_name())?;
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
    let laps = output::create_laps_output(&laps_with_metadata);
    let cars = preprocess::group_laps_by_car(laps_with_metadata);
    let car_count = cars.len();
    let metadata = output::create_metadata_output(event_name, &cars);

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
    let output_path = task.output_path();
    let laps_path = task.laps_path();

    fs::write(output_path, &output.metadata_json).map_err(|e| CliError::WriteFile {
        path: output_path.display().to_string(),
        source: e,
    })?;
    fs::write(&laps_path, &output.laps_json).map_err(|e| CliError::WriteFile {
        path: laps_path.display().to_string(),
        source: e,
    })?;

    Ok(WrittenFiles {
        metadata_path: output_path.to_path_buf(),
        laps_path,
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
