use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};

use crate::error::CliError;
use crate::pipeline::FileTask;

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
    pub fn build(mut args: impl Iterator<Item = String>) -> Result<Config, CliError> {
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

        let path = PathBuf::from(input_path.ok_or(CliError::MissingInputPath)?);

        if !path.exists() {
            Err(CliError::InputPathNotFound(path.display().to_string()))
        } else if path.is_dir() {
            if output_file.is_some() {
                return Err(CliError::OutputWithDirectory);
            }
            Ok(Config::BatchDirectory { dir_path: path })
        } else if path.is_file() {
            Ok(Config::SingleFile {
                file_path: path,
                output_file,
            })
        } else {
            Err(CliError::InvalidInputPath(path.display().to_string()))
        }
    }

    /// Config を処理単位（FileTask）のリストに変換
    pub fn into_tasks(self) -> Result<Vec<FileTask>, CliError> {
        match self {
            Config::SingleFile {
                file_path,
                output_file,
            } => {
                let (default_output, event_name) = Self::generate_output_names(&file_path);
                Ok(vec![FileTask {
                    input_path: file_path,
                    output_path: output_file.unwrap_or(default_output),
                    event_name,
                }])
            }
            Config::BatchDirectory { dir_path } => {
                let csv_files = find_csv_files(&dir_path)?;
                let tasks = csv_files
                    .into_iter()
                    .map(|csv_file| {
                        let (output, event) = Self::generate_output_names(&csv_file);
                        FileTask {
                            input_path: csv_file,
                            output_path: output,
                            event_name: event,
                        }
                    })
                    .collect();
                Ok(tasks)
            }
        }
    }

    /// 入力ファイル名から出力ファイル名とイベント名を生成
    pub fn generate_output_names(input_file: &Path) -> (PathBuf, String) {
        let stem = input_file
            .file_stem()
            .unwrap_or_else(|| OsStr::new("output"))
            .to_string_lossy();

        let output_file = input_file.with_extension("json");
        let event_name = stem.to_string();

        (output_file, event_name)
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
    fn config_build_no_input() {
        let args = vec!["program".to_string()];
        let result = Config::build(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn config_build_nonexistent_file() {
        let args = vec!["program".to_string(), "nonexistent.csv".to_string()];
        let result = Config::build(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn generate_output_names_basic() {
        let (output_file, event_name) = Config::generate_output_names(Path::new("input.csv"));
        assert_eq!(output_file, PathBuf::from("input.json"));
        assert_eq!(event_name, "input");
    }

    #[test]
    fn generate_output_names_with_path() {
        let (output_file, event_name) =
            Config::generate_output_names(Path::new("/path/to/input.csv"));
        assert_eq!(output_file, PathBuf::from("/path/to/input.json"));
        assert_eq!(event_name, "input");
    }

    #[test]
    fn generate_output_names_multiple_dots() {
        let (output_file, event_name) =
            Config::generate_output_names(Path::new("my.test.file.csv"));
        assert_eq!(output_file, PathBuf::from("my.test.file.json"));
        assert_eq!(event_name, "my.test.file");
    }

    #[test]
    fn generate_output_names_no_extension() {
        let (output_file, event_name) = Config::generate_output_names(Path::new("input"));
        assert_eq!(output_file, PathBuf::from("input.json"));
        assert_eq!(event_name, "input");
    }

    #[test]
    fn generate_output_names_relative_path() {
        let (output_file, event_name) =
            Config::generate_output_names(Path::new("./data/input.csv"));
        assert_eq!(output_file, PathBuf::from("./data/input.json"));
        assert_eq!(event_name, "input");
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
