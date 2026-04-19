use std::fs;
use std::path::{Path, PathBuf};

use crate::error::CliError;
use crate::pipeline::FileTask;

/// 引数パース結果（ファイルシステム未検証）
#[derive(Debug, PartialEq)]
struct RawArgs {
    input_path: PathBuf,
    output_file: Option<PathBuf>,
}

impl RawArgs {
    /// 純粋な引数パース（I/O なし）
    fn parse(mut args: impl Iterator<Item = String>) -> Result<Self, CliError> {
        args.next();

        let mut input_path = None;
        let mut output_file: Option<PathBuf> = None;

        while let Some(arg) = args.next() {
            if arg == "--output" {
                output_file = args.next().map(PathBuf::from);
            } else if input_path.is_none() {
                input_path = Some(arg);
            } else {
                return Err(CliError::UnexpectedArgument(arg));
            }
        }

        Ok(RawArgs {
            input_path: PathBuf::from(input_path.ok_or(CliError::MissingInputPath)?),
            output_file,
        })
    }

    /// ファイルシステムを参照して検証済み Config に変換
    fn resolve(self) -> Result<Config, CliError> {
        let path = self.input_path;

        if !path.exists() {
            Err(CliError::InputPathNotFound(path.display().to_string()))
        } else if path.is_dir() {
            if self.output_file.is_some() {
                return Err(CliError::OutputWithDirectory);
            }
            Ok(Config::BatchDirectory { dir_path: path })
        } else if path.is_file() {
            Ok(Config::SingleFile {
                file_path: path,
                output_file: self.output_file,
            })
        } else {
            Err(CliError::InvalidInputPath(path.display().to_string()))
        }
    }
}

#[derive(Debug)]
pub enum Config {
    SingleFile {
        file_path: PathBuf,
        output_file: Option<PathBuf>,
    },
    BatchDirectory {
        dir_path: PathBuf,
    },
}

impl Config {
    pub fn build(args: impl Iterator<Item = String>) -> Result<Config, CliError> {
        RawArgs::parse(args)?.resolve()
    }

    /// Config を処理単位（FileTask）のリストに変換
    pub fn into_tasks(self) -> Result<Vec<FileTask>, CliError> {
        match self {
            Config::SingleFile {
                file_path,
                output_file,
            } => Ok(vec![FileTask::new(file_path, output_file)]),
            Config::BatchDirectory { dir_path } => {
                let csv_files = find_csv_files(&dir_path)?;
                if csv_files.is_empty() {
                    return Err(CliError::NoCsvFilesFound(dir_path.display().to_string()));
                }
                let tasks = csv_files
                    .into_iter()
                    .map(|csv_file| FileTask::new(csv_file, None))
                    .collect();
                Ok(tasks)
            }
        }
    }
}

/// ディレクトリ内のCSVファイルを再帰的に検索
fn find_csv_files(dir_path: &Path) -> Result<Vec<PathBuf>, CliError> {
    let mut csv_files = Vec::new();
    let entries = fs::read_dir(dir_path).map_err(|e| CliError::ReadDir {
        path: dir_path.display().to_string(),
        source: e,
    })?;

    for entry in entries {
        let entry = entry.map_err(CliError::ReadDirEntry)?;
        let path = entry.path();

        if path.is_dir() {
            let mut subdir_files = find_csv_files(&path)?;
            csv_files.append(&mut subdir_files);
        } else if let Some(extension) = path.extension() {
            if extension == "csv" {
                csv_files.push(path);
            }
        }
    }

    Ok(csv_files)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use std::io::Write;
    use tempfile::tempdir;

    #[test]
    fn raw_args_parse_no_input() {
        let args = vec!["program".to_string()];
        let result = RawArgs::parse(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn raw_args_parse_input_only() {
        let args = vec!["program".to_string(), "input.csv".to_string()];
        let result = RawArgs::parse(args.into_iter()).unwrap();
        assert_eq!(
            result,
            RawArgs {
                input_path: PathBuf::from("input.csv"),
                output_file: None,
            }
        );
    }

    #[test]
    fn raw_args_parse_with_output() {
        let args = vec![
            "program".to_string(),
            "input.csv".to_string(),
            "--output".to_string(),
            "out.json".to_string(),
        ];
        let result = RawArgs::parse(args.into_iter()).unwrap();
        assert_eq!(
            result,
            RawArgs {
                input_path: PathBuf::from("input.csv"),
                output_file: Some(PathBuf::from("out.json")),
            }
        );
    }

    #[test]
    fn raw_args_parse_output_before_input() {
        let args = vec![
            "program".to_string(),
            "--output".to_string(),
            "out.json".to_string(),
            "input.csv".to_string(),
        ];
        let result = RawArgs::parse(args.into_iter()).unwrap();
        assert_eq!(
            result,
            RawArgs {
                input_path: PathBuf::from("input.csv"),
                output_file: Some(PathBuf::from("out.json")),
            }
        );
    }

    #[test]
    fn raw_args_parse_unexpected_argument() {
        let args = vec![
            "program".to_string(),
            "input.csv".to_string(),
            "extra".to_string(),
        ];
        let result = RawArgs::parse(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn config_build_nonexistent_file() {
        let args = vec!["program".to_string(), "nonexistent.csv".to_string()];
        let result = Config::build(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn file_task_default_output_basic() {
        let task = FileTask::new(PathBuf::from("input.csv"), None);
        assert_eq!(task.output_path(), Path::new("input.json"));
        assert_eq!(task.event_name(), "input");
    }

    #[test]
    fn file_task_default_output_with_path() {
        let task = FileTask::new(PathBuf::from("/path/to/input.csv"), None);
        assert_eq!(task.output_path(), Path::new("/path/to/input.json"));
        assert_eq!(task.event_name(), "input");
    }

    #[test]
    fn file_task_default_output_multiple_dots() {
        let task = FileTask::new(PathBuf::from("my.test.file.csv"), None);
        assert_eq!(task.output_path(), Path::new("my.test.file.json"));
        assert_eq!(task.event_name(), "my.test.file");
    }

    #[test]
    fn file_task_default_output_no_extension() {
        let task = FileTask::new(PathBuf::from("input"), None);
        assert_eq!(task.output_path(), Path::new("input.json"));
        assert_eq!(task.event_name(), "input");
    }

    #[test]
    fn file_task_default_output_relative_path() {
        let task = FileTask::new(PathBuf::from("./data/input.csv"), None);
        assert_eq!(task.output_path(), Path::new("./data/input.json"));
        assert_eq!(task.event_name(), "input");
    }

    #[test]
    fn file_task_with_output_override() {
        let task = FileTask::new(PathBuf::from("input.csv"), Some(PathBuf::from("custom.json")));
        assert_eq!(task.output_path(), Path::new("custom.json"));
        assert_eq!(task.event_name(), "input");
    }

    #[test]
    fn config_build_file_defers_name_resolution() {
        let temp_dir = tempdir().unwrap();
        let input_path = temp_dir.path().join("input.csv");

        File::create(&input_path)
            .unwrap()
            .write_all(b"test")
            .unwrap();

        let args = vec![
            "program".to_string(),
            input_path.to_string_lossy().to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        match &config {
            Config::SingleFile {
                file_path,
                output_file,
            } => {
                assert_eq!(file_path, &input_path);
                // output_file は --output 未指定なので None
                // 名前解決は into_tasks() で行われる
                assert_eq!(output_file, &None);
            }
            _ => panic!("Expected SingleFile config"),
        }
    }

    #[test]
    fn config_build_directory_with_output_is_error() {
        let temp_dir = tempdir().unwrap();

        let args = vec![
            "program".to_string(),
            temp_dir.path().to_string_lossy().to_string(),
            "--output".to_string(),
            "output.json".to_string(),
        ];

        let result = Config::build(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn config_build_with_directory() {
        let temp_dir = tempdir().unwrap();

        let args = vec![
            "program".to_string(),
            temp_dir.path().to_string_lossy().to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        match &config {
            Config::BatchDirectory { dir_path } => {
                assert_eq!(dir_path, temp_dir.path());
            }
            _ => panic!("Expected BatchDirectory config"),
        }
    }
}
