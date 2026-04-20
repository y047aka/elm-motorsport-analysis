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
                output_file = Some(PathBuf::from(
                    args.next().ok_or(CliError::MissingOutputValue)?,
                ));
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
            let csv_files = find_csv_files(&path)?;
            if csv_files.is_empty() {
                return Err(CliError::NoCsvFilesFound(path.display().to_string()));
            }
            Ok(Config::BatchDirectory { csv_files })
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
        csv_files: Vec<PathBuf>,
    },
}

impl Config {
    pub fn build(args: impl Iterator<Item = String>) -> Result<Config, CliError> {
        RawArgs::parse(args)?.resolve()
    }

    /// Config を処理単位（FileTask）のリストに変換（純粋な変換）
    pub fn into_tasks(self) -> Vec<FileTask> {
        match self {
            Config::SingleFile {
                file_path,
                output_file,
            } => vec![FileTask::new(file_path, output_file)],
            Config::BatchDirectory { csv_files } => csv_files
                .into_iter()
                .map(|csv_file| FileTask::new(csv_file, None))
                .collect(),
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
    fn raw_args_parse_output_without_value() {
        let args = vec![
            "program".to_string(),
            "input.csv".to_string(),
            "--output".to_string(),
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
    fn config_build_single_file_without_output() {
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
    fn config_build_empty_directory_is_error() {
        let temp_dir = tempdir().unwrap();

        let args = vec![
            "program".to_string(),
            temp_dir.path().to_string_lossy().to_string(),
        ];

        let result = Config::build(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn config_build_with_directory() {
        let temp_dir = tempdir().unwrap();
        File::create(temp_dir.path().join("race.csv"))
            .unwrap()
            .write_all(b"test")
            .unwrap();

        let args = vec![
            "program".to_string(),
            temp_dir.path().to_string_lossy().to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        match &config {
            Config::BatchDirectory { csv_files } => {
                assert_eq!(csv_files.len(), 1);
                assert_eq!(csv_files[0], temp_dir.path().join("race.csv"));
            }
            _ => panic!("Expected BatchDirectory config"),
        }
    }
}
