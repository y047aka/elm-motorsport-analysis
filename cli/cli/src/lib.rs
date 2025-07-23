use std::error::Error;
use std::fs;
use std::path::Path;
use std::io::Write;

use motorsport::{Duration, duration};

use anyhow::Result;
use serde::{Deserialize, Serialize};

pub mod preprocess;
pub use preprocess::{parse_laps_from_csv, group_laps_by_car};

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

/// WECラップデータ構造体（Elmの実装を参考）
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct WecLap {
    #[serde(rename = "NUMBER")]
    pub car_number: String,
    #[serde(rename = "DRIVER_NUMBER")]
    pub driver_number: u32,
    #[serde(rename = "LAP_NUMBER")]
    pub lap_number: u32,
    #[serde(rename = "LAP_TIME", deserialize_with = "deserialize_duration")]
    pub lap_time: Duration,
    #[serde(rename = "LAP_IMPROVEMENT")]
    pub lap_improvement: i32,
    #[serde(rename = "CROSSING_FINISH_LINE_IN_PIT")]
    pub crossing_finish_line_in_pit: String,
    #[serde(rename = "S1", deserialize_with = "deserialize_optional_duration")]
    pub s1: Option<Duration>,
    #[serde(rename = "S1_IMPROVEMENT")]
    pub s1_improvement: i32,
    #[serde(rename = "S2", deserialize_with = "deserialize_optional_duration")]
    pub s2: Option<Duration>,
    #[serde(rename = "S2_IMPROVEMENT")]
    pub s2_improvement: i32,
    #[serde(rename = "S3", deserialize_with = "deserialize_optional_duration")]
    pub s3: Option<Duration>,
    #[serde(rename = "S3_IMPROVEMENT")]
    pub s3_improvement: i32,
    #[serde(rename = "KPH")]
    pub kph: f64,
    #[serde(rename = "ELAPSED", deserialize_with = "deserialize_duration")]
    pub elapsed: Duration,
    #[serde(rename = "HOUR", deserialize_with = "deserialize_duration")]
    pub hour: Duration,
    #[serde(rename = "TOP_SPEED", deserialize_with = "deserialize_optional_f64")]
    pub top_speed: Option<f64>,
    #[serde(rename = "DRIVER_NAME")]
    pub driver_name: String,
    #[serde(rename = "PIT_TIME", deserialize_with = "deserialize_optional_duration")]
    pub pit_time: Option<Duration>,
    #[serde(rename = "CLASS")]
    pub class: String,
    #[serde(rename = "GROUP")]
    pub group: String,
    #[serde(rename = "TEAM")]
    pub team: String,
    #[serde(rename = "MANUFACTURER")]
    pub manufacturer: String,
}

/// カスタムデシリアライザー：Duration文字列をミリ秒に変換
fn deserialize_duration<'de, D>(deserializer: D) -> Result<Duration, D::Error>
where
    D: serde::Deserializer<'de>,
{
    String::deserialize(deserializer)
        .and_then(|s| {
            duration::from_string(&s).ok_or_else(|| serde::de::Error::custom("Invalid duration format"))
        })
}

/// カスタムデシリアライザー：オプショナルDuration文字列をミリ秒に変換
fn deserialize_optional_duration<'de, D>(deserializer: D) -> Result<Option<Duration>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    String::deserialize(deserializer).map(|s| {
        if s.is_empty() {
            None
        } else {
            duration::from_string(&s)
        }
    })
}

/// カスタムデシリアライザー：オプショナルf64
fn deserialize_optional_f64<'de, D>(deserializer: D) -> Result<Option<f64>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    String::deserialize(deserializer)
        .map(|s| {
            if s.is_empty() {
                None
            } else {
                s.parse::<f64>().ok()
            }
        })
}

/// CSV読み込み関数
pub fn read_csv<P: AsRef<Path>>(path: P) -> Result<Vec<WecLap>> {
    fs::File::open(path)
        .map_err(Into::into)
        .and_then(|file| {
            csv::ReaderBuilder::new()
                .delimiter(b';')
                .from_reader(file)
                .deserialize()
                .collect::<Result<Vec<WecLap>, _>>()
                .map_err(Into::into)
        })
}

/// メイン実行関数
pub fn run(config: Config) -> Result<(), Box<dyn Error>> {
    let csv_content = fs::read_to_string(&config.input_file)?;
    let laps = parse_laps_from_csv(&csv_content);
    println!("Read {} laps", laps.len());

    let cars = group_laps_by_car(laps);
    let json = serde_json::to_string_pretty(&cars)?;

    // 出力ファイル名（指定がなければ test.json）
    let output_path = config.output_file.as_deref().unwrap_or("test.json");
    let mut file = fs::File::create(output_path)?;
    file.write_all(json.as_bytes())?;
    println!("Wrote JSON to {}", output_path);
    Ok(())
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
