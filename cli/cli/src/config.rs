use std::error::Error;
use std::ffi::OsStr;
use std::path::Path;

#[derive(Debug)]
pub enum InputType {
    File(String),
    Directory(String),
}

#[derive(Debug)]
pub struct Config {
    pub input_type: InputType,
    pub output_file: Option<String>,
    pub event_name: Option<String>,
}

impl Config {
    pub fn build(mut args: impl Iterator<Item = String>) -> Result<Config, Box<dyn Error>> {
        args.next();

        let mut input_path = None;
        let mut output_file = None;

        while let Some(arg) = args.next() {
            if arg == "--output" {
                output_file = args.next();
            } else if input_path.is_none() {
                input_path = Some(arg);
            } else {
                return Err(format!("Unexpected argument: {arg}").into());
            }
        }

        let input_path = input_path
            .ok_or_else(|| -> Box<dyn Error> { "Missing required input path argument".into() })?;

        let path = Path::new(&input_path);
        let input_type = if !path.exists() {
            return Err(format!("Input path does not exist: {input_path}").into());
        } else if path.is_dir() {
            InputType::Directory(input_path)
        } else if path.is_file() {
            InputType::File(input_path)
        } else {
            return Err(format!("Input path is neither a file nor directory: {input_path}").into());
        };

        // output_fileが指定されていない場合はデフォルト値を生成
        let output_file = output_file.or_else(|| match &input_type {
            InputType::File(file_path) => {
                let (default_output, _) = Self::generate_output_names(file_path);
                Some(default_output)
            }
            InputType::Directory(_) => None,
        });

        // event_nameは常にデフォルト値を使用
        let event_name = match &input_type {
            InputType::File(file_path) => {
                let (_, default_event) = Self::generate_output_names(file_path);
                Some(default_event)
            }
            InputType::Directory(_) => None,
        };

        Ok(Config {
            input_type,
            output_file,
            event_name,
        })
    }

    /// 入力ファイル名から出力ファイル名とイベント名を生成
    pub fn generate_output_names(input_file: &str) -> (String, String) {
        let path = Path::new(input_file);
        let stem = path
            .file_stem()
            .unwrap_or_else(|| OsStr::new("output"))
            .to_string_lossy();

        let output_file = path.with_extension("json").to_string_lossy().to_string();
        let event_name = stem.to_string();

        (output_file, event_name)
    }
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
        let (output_file, event_name) = Config::generate_output_names("input.csv");
        assert_eq!(output_file, "input.json");
        assert_eq!(event_name, "input");
    }

    #[test]
    fn generate_output_names_with_path() {
        let (output_file, event_name) = Config::generate_output_names("/path/to/input.csv");
        assert_eq!(output_file, "/path/to/input.json");
        assert_eq!(event_name, "input");
    }

    #[test]
    fn generate_output_names_multiple_dots() {
        let (output_file, event_name) = Config::generate_output_names("my.test.file.csv");
        assert_eq!(output_file, "my.test.file.json");
        assert_eq!(event_name, "my.test.file");
    }

    #[test]
    fn generate_output_names_no_extension() {
        let (output_file, event_name) = Config::generate_output_names("input");
        assert_eq!(output_file, "input.json");
        assert_eq!(event_name, "input");
    }

    #[test]
    fn generate_output_names_relative_path() {
        let (output_file, event_name) = Config::generate_output_names("./data/input.csv");
        assert_eq!(output_file, "./data/input.json");
        assert_eq!(event_name, "input");
    }

    #[test]
    fn config_build_file_auto_names() {
        let temp_dir = tempdir().unwrap();
        let input_path = temp_dir.path().join("input.csv");
        let expected_output = temp_dir.path().join("input.json");

        File::create(&input_path)
            .unwrap()
            .write_all(b"test")
            .unwrap();

        let args = vec![
            "program".to_string(),
            input_path.to_string_lossy().to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        match &config.input_type {
            InputType::File(file_path) => {
                assert_eq!(file_path, &input_path.to_string_lossy().to_string());
            }
            _ => panic!("Expected File input type"),
        }
        // 自動生成された名前が設定されていることを確認
        assert_eq!(
            config.output_file,
            Some(expected_output.to_string_lossy().to_string())
        );
        assert_eq!(config.event_name, Some("input".to_string()));
    }

    #[test]
    fn config_build_with_directory() {
        let temp_dir = tempdir().unwrap();

        let args = vec![
            "program".to_string(),
            temp_dir.path().to_string_lossy().to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        match &config.input_type {
            InputType::Directory(dir_path) => {
                assert_eq!(dir_path, &temp_dir.path().to_string_lossy().to_string());
            }
            _ => panic!("Expected Directory input type"),
        }
        // ディレクトリの場合はoutput_fileはNoneになる
        assert_eq!(config.output_file, None);
        assert_eq!(config.event_name, None);
    }
}
