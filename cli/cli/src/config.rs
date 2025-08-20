use std::error::Error;
use std::ffi::OsStr;
use std::path::Path;

#[derive(Debug)]
pub struct Config {
    pub input_file: String,
    pub output_file: Option<String>,
    pub event_name: Option<String>,
}

impl Config {
    pub fn build(mut args: impl Iterator<Item = String>) -> Result<Config, Box<dyn Error>> {
        args.next();

        let input_file = args
            .next()
            .ok_or_else(|| -> Box<dyn Error> { "Missing required input file argument".into() })
            .and_then(|file| {
                if Path::new(&file).exists() {
                    Ok(file)
                } else {
                    Err(format!("Input file does not exist: {file}").into())
                }
            })?;

        let output_file = args.next();
        let event_name = args.next();

        // デフォルト値として自動生成された名前を使用
        let (default_output, default_event) = Self::generate_output_names(&input_file);

        Ok(Config {
            input_file,
            output_file: output_file.or(Some(default_output)),
            event_name: event_name.or(Some(default_event)),
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
    fn config_build_with_existing_file() {
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
        assert_eq!(config.input_file, input_path.to_string_lossy().to_string());
        // 自動生成された名前が設定されていることを確認（同じディレクトリ）
        let expected_output = input_path.with_extension("json");
        assert_eq!(
            config.output_file,
            Some(expected_output.to_string_lossy().to_string())
        );
        assert_eq!(config.event_name, Some("input".to_string()));
    }

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
    fn config_build_with_auto_generated_names() {
        let temp_dir = tempdir().unwrap();
        let input_path = temp_dir.path().join("my_data.csv");
        let expected_output = temp_dir.path().join("my_data.json");

        File::create(&input_path)
            .unwrap()
            .write_all(b"test")
            .unwrap();

        let args = vec![
            "program".to_string(),
            input_path.to_string_lossy().to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        assert_eq!(config.input_file, input_path.to_string_lossy().to_string());
        // 自動生成された名前が設定されていることを確認
        assert_eq!(
            config.output_file,
            Some(expected_output.to_string_lossy().to_string())
        );
        assert_eq!(config.event_name, Some("my_data".to_string()));
    }

    #[test]
    fn config_build_with_custom_names() {
        let temp_dir = tempdir().unwrap();
        let input_path = temp_dir.path().join("input.csv");
        let output_path = temp_dir.path().join("custom_output.json");

        File::create(&input_path)
            .unwrap()
            .write_all(b"test")
            .unwrap();

        let args = vec![
            "program".to_string(),
            input_path.to_string_lossy().to_string(),
            output_path.to_string_lossy().to_string(),
            "Custom Event".to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        assert_eq!(config.input_file, input_path.to_string_lossy().to_string());
        // カスタム名が設定されていることを確認
        assert_eq!(
            config.output_file,
            Some(output_path.to_string_lossy().to_string())
        );
        assert_eq!(config.event_name, Some("Custom Event".to_string()));
    }
}
