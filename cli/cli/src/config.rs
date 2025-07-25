/// CLI設定構造体
#[derive(Debug, Clone)]
pub struct Config {
    pub input_file: String,
    pub output_file: Option<String>,
    pub event_name: Option<String>,
}

impl Config {
    pub fn build(mut args: impl Iterator<Item = String>) -> Result<Config, &'static str> {
        args.next();

        let input_file = match args.next() {
            Some(arg) => arg,
            None => return Err("Didn't get a input file string"),
        };

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

    #[test]
    fn config_build() {
        let args = vec![
            "program".to_string(),
            "input.csv".to_string(),
            "output.json".to_string(),
            "test_event".to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        assert_eq!(config.input_file, "input.csv");
        assert_eq!(config.output_file, Some("output.json".to_string()));
        assert_eq!(config.event_name, Some("test_event".to_string()));
    }

    #[test]
    fn config_build_minimal() {
        let args = vec![
            "program".to_string(),
            "input.csv".to_string(),
        ];

        let config = Config::build(args.into_iter()).unwrap();
        assert_eq!(config.input_file, "input.csv");
        assert_eq!(config.output_file, None);
        assert_eq!(config.event_name, None);
    }

    #[test]
    fn config_build_no_input() {
        let args = vec!["program".to_string()];

        let result = Config::build(args.into_iter());
        assert!(result.is_err());
    }
}