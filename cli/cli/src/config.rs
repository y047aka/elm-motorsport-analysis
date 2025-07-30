use std::error::Error;
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

        Ok(Config {
            input_file,
            output_file,
            event_name,
        })
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
        let output_path = temp_dir.path().join("output.json");

        File::create(&input_path)
            .unwrap()
            .write_all(b"test")
            .unwrap();

        let args = vec![
            "program".to_string(),
            input_path.to_string_lossy().to_string(),
            output_path.to_string_lossy().to_string(),
            "test_event".to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        assert_eq!(config.input_file, input_path.to_string_lossy().to_string());
        assert_eq!(
            config.output_file,
            Some(output_path.to_string_lossy().to_string())
        );
        assert_eq!(config.event_name, Some("test_event".to_string()));
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
}
