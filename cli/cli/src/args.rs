use std::path::{Path, PathBuf};

use crate::FileTask;
use crate::error::SetupError;

/// 引数パース結果（ファイルシステム未検証）
#[derive(Debug, PartialEq)]
struct RawArgs {
    input_path: PathBuf,
    output_file: Option<PathBuf>,
    validate: bool,
}

impl RawArgs {
    /// 純粋な引数パース（I/O なし）
    fn parse(mut args: impl Iterator<Item = String>) -> Result<Self, SetupError> {
        enum ParseState {
            Ready {
                input: Option<String>,
                output: Option<PathBuf>,
            },
            ExpectingOutputValue {
                input: Option<String>,
            },
        }
        args.next();

        let mut validate = false;

        let final_state = args.try_fold(
            ParseState::Ready {
                input: None,
                output: None,
            },
            |state, arg| match state {
                ParseState::ExpectingOutputValue { input } => Ok(ParseState::Ready {
                    input,
                    output: Some(PathBuf::from(arg)),
                }),
                ParseState::Ready { input, output } if arg == "--validate" => {
                    validate = true;
                    Ok(ParseState::Ready { input, output })
                }
                ParseState::Ready {
                    input,
                    output: None,
                } if arg == "--output" => Ok(ParseState::ExpectingOutputValue { input }),
                ParseState::Ready {
                    output: Some(_), ..
                } if arg == "--output" => Err(SetupError::DuplicateOutput),
                ParseState::Ready {
                    input: None,
                    output,
                } => Ok(ParseState::Ready {
                    input: Some(arg),
                    output,
                }),
                ParseState::Ready {
                    input: Some(_), ..
                } => Err(SetupError::UnexpectedArgument(arg)),
            },
        )?;

        match final_state {
            ParseState::Ready {
                input: Some(input),
                output,
            } => Ok(RawArgs {
                input_path: PathBuf::from(input),
                output_file: output,
                validate,
            }),
            ParseState::Ready { input: None, .. } => Err(SetupError::MissingInputPath),
            ParseState::ExpectingOutputValue { .. } => Err(SetupError::MissingOutputValue),
        }
    }

    /// ファイルシステムを参照して検証済み FileTask のリストに変換
    fn resolve(self) -> Result<Vec<FileTask>, SetupError> {
        enum PathKind {
            NotFound,
            File,
            Dir,
            Other,
        }

        fn classify_path(path: &Path) -> PathKind {
            if !path.exists() {
                PathKind::NotFound
            } else if path.is_file() {
                PathKind::File
            } else if path.is_dir() {
                PathKind::Dir
            } else {
                PathKind::Other
            }
        }

        let path = self.input_path;

        match classify_path(&path) {
            PathKind::NotFound => Err(SetupError::InputPathNotFound(path)),
            PathKind::File => Ok(vec![FileTask::new(path, self.output_file, self.validate)]),
            PathKind::Dir => resolve_dir(path, self.output_file, self.validate),
            PathKind::Other => Err(SetupError::InvalidInputPath(path)),
        }
    }
}

fn resolve_dir(
    path: PathBuf,
    output_file: Option<PathBuf>,
    validate: bool,
) -> Result<Vec<FileTask>, SetupError> {
    if output_file.is_some() {
        return Err(SetupError::OutputWithDirectory);
    }
    let csv_files = find_csv_files(&path).map_err(|source| SetupError::WalkDir {
        path: path.clone(),
        source,
    })?;
    if csv_files.is_empty() {
        return Err(SetupError::NoCsvFilesFound(path));
    }
    Ok(csv_files
        .into_iter()
        .map(|f| FileTask::new(f, None, validate))
        .collect())
}

/// CLI 引数をパースし、検証済みの処理タスクリストを返す
pub fn parse_args(args: impl Iterator<Item = String>) -> Result<Vec<FileTask>, SetupError> {
    RawArgs::parse(args)?.resolve()
}

/// ディレクトリ内のCSVファイルを再帰的に検索
fn find_csv_files(dir_path: &Path) -> Result<Vec<PathBuf>, walkdir::Error> {
    walkdir::WalkDir::new(dir_path)
        .into_iter()
        .map(|entry| entry.map(|e| e.into_path()))
        .collect::<Result<Vec<_>, _>>()
        .map(|paths| {
            paths
                .into_iter()
                .filter(|p| p.extension().is_some_and(|ext| ext == "csv"))
                .collect()
        })
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
                validate: false,
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
                validate: false,
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
                validate: false,
            }
        );
    }

    #[test]
    fn raw_args_parse_with_validate_flag() {
        let args = vec![
            "program".to_string(),
            "input.csv".to_string(),
            "--validate".to_string(),
        ];
        let result = RawArgs::parse(args.into_iter()).unwrap();
        assert_eq!(
            result,
            RawArgs {
                input_path: PathBuf::from("input.csv"),
                output_file: None,
                validate: true,
            }
        );
    }

    #[test]
    fn raw_args_parse_validate_before_input() {
        let args = vec![
            "program".to_string(),
            "--validate".to_string(),
            "input.csv".to_string(),
        ];
        let result = RawArgs::parse(args.into_iter()).unwrap();
        assert_eq!(
            result,
            RawArgs {
                input_path: PathBuf::from("input.csv"),
                output_file: None,
                validate: true,
            }
        );
    }

    #[test]
    fn raw_args_parse_validate_with_output() {
        let args = vec![
            "program".to_string(),
            "--validate".to_string(),
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
                validate: true,
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
    fn raw_args_parse_duplicate_output() {
        let args = vec![
            "program".to_string(),
            "--output".to_string(),
            "a.json".to_string(),
            "--output".to_string(),
            "b.json".to_string(),
            "input.csv".to_string(),
        ];
        let result = RawArgs::parse(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn parse_args_nonexistent_file() {
        let args = vec!["program".to_string(), "nonexistent.csv".to_string()];
        let result = parse_args(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn parse_args_single_file_without_output() {
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

        let tasks = parse_args(args.into_iter()).unwrap();
        assert_eq!(tasks.len(), 1);
        assert_eq!(tasks[0].input_path(), &input_path);
        assert_eq!(tasks[0].output_path(), input_path.with_extension("json"));
    }

    #[test]
    fn parse_args_directory_with_output_is_error() {
        let temp_dir = tempdir().unwrap();

        let args = vec![
            "program".to_string(),
            temp_dir.path().to_string_lossy().to_string(),
            "--output".to_string(),
            "output.json".to_string(),
        ];

        let result = parse_args(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn parse_args_empty_directory_is_error() {
        let temp_dir = tempdir().unwrap();

        let args = vec![
            "program".to_string(),
            temp_dir.path().to_string_lossy().to_string(),
        ];

        let result = parse_args(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn parse_args_with_directory() {
        let temp_dir = tempdir().unwrap();
        File::create(temp_dir.path().join("race.csv"))
            .unwrap()
            .write_all(b"test")
            .unwrap();

        let args = vec![
            "program".to_string(),
            temp_dir.path().to_string_lossy().to_string(),
        ];

        let tasks = parse_args(args.into_iter()).unwrap();
        assert_eq!(tasks.len(), 1);
        assert_eq!(tasks[0].input_path(), temp_dir.path().join("race.csv"));
    }
}
