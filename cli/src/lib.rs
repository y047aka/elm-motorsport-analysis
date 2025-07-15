use std::error::Error;
use std::fs;
use std::path::Path;

use anyhow::Result;
use serde::{Deserialize, Serialize};

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

pub type Duration = u32;

pub mod duration {
    use super::Duration;

    /// Duration文字列をミリ秒に変換
    /// 例: "1:35.365" -> 95365, "23.155" -> 23155
    pub fn from_string(s: &str) -> Option<Duration> {
        let parts: Vec<&str> = s.split(':').collect();

        match parts.as_slice() {
            // "hh:mm:ss.ms" 形式
            [h, m, s] => {
                let hours = h.parse::<u32>().ok()?;
                let minutes = m.parse::<u32>().ok()?;
                let seconds = s.parse::<f64>().ok()?;
                Some(hours * 3600000 + minutes * 60000 + (seconds * 1000.0) as u32)
            }
            // "mm:ss.ms" 形式
            [m, s] => {
                let minutes = m.parse::<u32>().ok()?;
                let seconds = s.parse::<f64>().ok()?;
                Some(minutes * 60000 + (seconds * 1000.0) as u32)
            }
            // "ss.ms" 形式
            [s] => {
                let seconds = s.parse::<f64>().ok()?;
                Some((seconds * 1000.0) as u32)
            }
            _ => None,
        }
    }

    /// ミリ秒をDuration文字列に変換
    pub fn to_string(ms: Duration) -> String {
        if ms >= 3600000 {
            // 1時間以上
            let hours = ms / 3600000;
            let minutes = (ms % 3600000) / 60000;
            let seconds = ((ms % 60000) as f64) / 1000.0;
            format!("{}:{:02}:{:06.3}", hours, minutes, seconds)
        } else if ms >= 60000 {
            // 1分以上
            let minutes = ms / 60000;
            let seconds = ((ms % 60000) as f64) / 1000.0;
            format!("{}:{:06.3}", minutes, seconds)
        } else {
            // 1分未満
            let seconds = (ms as f64) / 1000.0;
            format!("{:.3}", seconds)
        }
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
    let laps = read_csv(&config.input_file)?;

    println!("Read {} laps", laps.len());
    laps.iter()
        .take(3)
        .for_each(|lap| {
            println!("車両 {}: ラップ {} - {}",
                lap.car_number,
                lap.lap_number,
                duration::to_string(lap.lap_time)
            );
        });

    Ok(())
}

/// Motorsportライブラリ - Elmから移植
pub mod motorsport {
    use serde::{Deserialize, Serialize};

    /// レースクラス/カテゴリーの定義
    #[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
    pub enum Class {
        None,
        LMH,
        LMP1,
        LMP2,
        LMGTEPro,
        LMGTEAm,
        LMGT3,
        InnovativeCar,
    }

    impl Class {
        /// クラスを文字列に変換（ElmのtoStringと互換）
        pub fn to_string(&self) -> &'static str {
            match self {
                Class::None => "None",
                Class::LMH => "HYPERCAR",
                Class::LMP1 => "LMP1",
                Class::LMP2 => "LMP2",
                Class::LMGTEPro => "LMGTE Pro",
                Class::LMGTEAm => "LMGTE Am",
                Class::LMGT3 => "LMGT3",
                Class::InnovativeCar => "INNOVATIVE CAR",
            }
        }

        /// 文字列からクラスを生成（ElmのfromStringと互換）
        pub fn from_string(s: &str) -> Option<Self> {
            match s {
                "None" => Some(Class::None),
                "HYPERCAR" => Some(Class::LMH),
                "LMP1" => Some(Class::LMP1),
                "LMP2" => Some(Class::LMP2),
                "LMGTE Pro" => Some(Class::LMGTEPro),
                "LMGTE Am" => Some(Class::LMGTEAm),
                "LMGT3" => Some(Class::LMGT3),
                "INNOVATIVE CAR" => Some(Class::InnovativeCar),
                _ => None,
            }
        }

        /// クラスの16進数カラーコードを取得（ElmのtoHexColorを簡略化）
        pub fn to_hex_color(&self, season: u32) -> &'static str {
            match self {
                Class::None => "#000",
                Class::LMH => "#f00",
                Class::LMP1 => "#f00",
                Class::LMP2 => "#00f",
                Class::LMGTEPro => "#060",
                Class::LMGTEAm => "#f60",
                Class::LMGT3 => {
                    if season > 2024 {
                        "#060"
                    } else {
                        "#f60"
                    }
                }
                Class::InnovativeCar => "#00f",
            }
        }
    }

    /// ドライバー情報
    #[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
    pub struct Driver {
        pub name: String,
        pub is_current_driver: bool,
    }

    impl Driver {
        /// 新しいドライバーを作成
        pub fn new(name: String, is_current: bool) -> Self {
            Driver {
                name,
                is_current_driver: is_current,
            }
        }
    }

    /// ドライバーリストから現在のドライバーを検索
    pub fn find_current_driver(drivers: &[Driver]) -> Option<&Driver> {
        drivers.iter().find(|d| d.is_current_driver)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::io::Write;
    use motorsport::*;

    #[test]
    fn test_duration_from_string() {
        assert_eq!(duration::from_string("1:35.365"), Some(95365));
        assert_eq!(duration::from_string("23.155"), Some(23155));
        assert_eq!(duration::from_string("0:29.928"), Some(29928));
        assert_eq!(duration::from_string("7:06:54.321"), Some(25614321));
    }

    #[test]
    fn test_duration_to_string() {
        assert_eq!(duration::to_string(95365), "1:35.365");
        assert_eq!(duration::to_string(23155), "23.155");
        assert_eq!(duration::to_string(29928), "29.928");
        assert_eq!(duration::to_string(25614321), "7:06:54.321");
    }

    #[test]
    fn test_config_build() {
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
    fn test_config_build_minimal() {
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
    fn test_config_build_no_input() {
        let args = vec!["program".to_string()];

        let result = Config::build(args.into_iter());
        assert!(result.is_err());
    }

    #[test]
    fn test_csv_parsing() {
        let csv_content = r#"NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;
12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;
7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.782;0:23.119;0:29.188;0:40.984;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.119;29.188;40.984;"#;

        let temp_file = "test_temp.csv";
        let mut file = fs::File::create(temp_file).unwrap();
        file.write_all(csv_content.as_bytes()).unwrap();

        let result = read_csv(temp_file);
        assert!(result.is_ok());

        let laps = result.unwrap();
        assert_eq!(laps.len(), 2);

        // 最初のラップをテスト
        let first_lap = &laps[0];
        assert_eq!(first_lap.car_number, "12");
        assert_eq!(first_lap.driver_number, 1);
        assert_eq!(first_lap.lap_number, 1);
        assert_eq!(first_lap.lap_time, 95365); // 1:35.365 = 95365ms
        assert_eq!(first_lap.driver_name, "Will STEVENS");
        assert_eq!(first_lap.class, "HYPERCAR");
        assert_eq!(first_lap.team, "Hertz Team JOTA");
        assert_eq!(first_lap.manufacturer, "Porsche");
        assert_eq!(first_lap.s1, Some(23155)); // 23.155 = 23155ms
        assert_eq!(first_lap.s2, Some(29928)); // 29.928 = 29928ms
        assert_eq!(first_lap.s3, Some(42282)); // 42.282 = 42282ms

        // 2番目のラップをテスト
        let second_lap = &laps[1];
        assert_eq!(second_lap.car_number, "7");
        assert_eq!(second_lap.driver_name, "Kamui KOBAYASHI");
        assert_eq!(second_lap.lap_time, 93291); // 1:33.291 = 93291ms

        fs::remove_file(temp_file).unwrap();
    }

    #[test]
    fn test_class_to_string() {
        // Elmの実装と互換性を確認
        assert_eq!(Class::None.to_string(), "None");
        assert_eq!(Class::LMH.to_string(), "HYPERCAR");
        assert_eq!(Class::LMP1.to_string(), "LMP1");
        assert_eq!(Class::LMP2.to_string(), "LMP2");
        assert_eq!(Class::LMGTEPro.to_string(), "LMGTE Pro");
        assert_eq!(Class::LMGTEAm.to_string(), "LMGTE Am");
        assert_eq!(Class::LMGT3.to_string(), "LMGT3");
        assert_eq!(Class::InnovativeCar.to_string(), "INNOVATIVE CAR");
    }

    #[test]
    fn test_class_from_string() {
        // 正常なケース
        assert_eq!(Class::from_string("None"), Some(Class::None));
        assert_eq!(Class::from_string("HYPERCAR"), Some(Class::LMH));
        assert_eq!(Class::from_string("LMP1"), Some(Class::LMP1));
        assert_eq!(Class::from_string("LMP2"), Some(Class::LMP2));
        assert_eq!(Class::from_string("LMGTE Pro"), Some(Class::LMGTEPro));
        assert_eq!(Class::from_string("LMGTE Am"), Some(Class::LMGTEAm));
        assert_eq!(Class::from_string("LMGT3"), Some(Class::LMGT3));
        assert_eq!(Class::from_string("INNOVATIVE CAR"), Some(Class::InnovativeCar));

        // 不正なケース
        assert_eq!(Class::from_string("UNKNOWN"), None);
        assert_eq!(Class::from_string(""), None);
        assert_eq!(Class::from_string("lmp1"), None); // 大文字小文字の区別
    }

    #[test]
    fn test_class_round_trip() {
        // 文字列変換の往復テスト
        let classes = vec![
            Class::None,
            Class::LMH,
            Class::LMP1,
            Class::LMP2,
            Class::LMGTEPro,
            Class::LMGTEAm,
            Class::LMGT3,
            Class::InnovativeCar,
        ];

        for class in classes {
            let string_repr = class.to_string();
            let parsed_class = Class::from_string(string_repr);
            assert_eq!(Some(class), parsed_class);
        }
    }

    #[test]
    fn test_class_hex_colors() {
        // 2024年シーズンのカラー
        assert_eq!(Class::None.to_hex_color(2024), "#000");
        assert_eq!(Class::LMH.to_hex_color(2024), "#f00");
        assert_eq!(Class::LMP1.to_hex_color(2024), "#f00");
        assert_eq!(Class::LMP2.to_hex_color(2024), "#00f");
        assert_eq!(Class::LMGTEPro.to_hex_color(2024), "#060");
        assert_eq!(Class::LMGTEAm.to_hex_color(2024), "#f60");
        assert_eq!(Class::LMGT3.to_hex_color(2024), "#f60");
        assert_eq!(Class::InnovativeCar.to_hex_color(2024), "#00f");

        // 2025年以降（LMGT3のカラーが変わる）
        assert_eq!(Class::LMGT3.to_hex_color(2025), "#060");
    }

    #[test]
    fn test_find_current_driver() {
        let drivers = vec![
            Driver::new("Will STEVENS".to_string(), false),
            Driver::new("Kamui KOBAYASHI".to_string(), true),
            Driver::new("Mike CONWAY".to_string(), false),
        ];

        let current = find_current_driver(&drivers);
        assert!(current.is_some());
        assert_eq!(current.unwrap().name, "Kamui KOBAYASHI");
    }

    #[test]
    fn test_find_current_driver_none() {
        let drivers = vec![
            Driver::new("Will STEVENS".to_string(), false),
            Driver::new("Mike CONWAY".to_string(), false),
        ];

        let current = find_current_driver(&drivers);
        assert!(current.is_none());
    }

    #[test]
    fn test_find_current_driver_empty() {
        let drivers: Vec<Driver> = vec![];
        let current = find_current_driver(&drivers);
        assert!(current.is_none());
    }
}
