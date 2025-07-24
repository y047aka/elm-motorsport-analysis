use std::error::Error;
use std::fs;
use std::io::Write;

use anyhow::Result;
use serde::Serialize;
use motorsport::{Car, duration};

pub mod preprocess;
pub use preprocess::{parse_laps_from_csv, group_laps_by_car, LapWithMetadata};

/// Elm互換の3層出力構造
#[derive(Debug, Serialize)]
pub struct ElmCompatibleOutput {
    pub name: String,
    pub laps: Vec<ElmRawLap>,
    pub preprocessed: Vec<ElmPreprocessedCar>,
}

/// Raw lap data format (laps配列の要素)
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ElmRawLap {
    pub car_number: String,
    pub driver_number: u32,
    pub lap_number: u32,
    pub lap_time: String,
    pub lap_improvement: i32,
    pub crossing_finish_line_in_pit: String,
    pub s1: String,
    pub s1_improvement: i32,
    pub s2: String,
    pub s2_improvement: i32,
    pub s3: String,
    pub s3_improvement: i32,
    pub kph: f32,
    pub elapsed: String,
    pub hour: String,
    pub top_speed: String,
    pub driver_name: String,
    pub pit_time: String,
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
}

/// Preprocessed car data format (preprocessed配列の要素)
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ElmPreprocessedCar {
    pub car_number: String,
    pub drivers: Vec<ElmDriver>,
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
    pub start_position: i32,
    pub laps: Vec<ElmPreprocessedLap>,
    pub current_lap: Option<ElmPreprocessedLap>,
    pub last_lap: Option<ElmPreprocessedLap>,
}

/// Driver format (drivers配列の要素)
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ElmDriver {
    pub name: String,
    pub is_current_driver: bool,
}

/// Preprocessed lap format (車両内のlaps配列の要素)
#[derive(Debug, Serialize)]
pub struct ElmPreprocessedLap {
    #[serde(rename = "carNumber")]
    pub car_number: String,
    pub driver: String,
    pub lap: u32,
    pub position: Option<u32>,
    pub time: String,
    pub best: String,
    pub sector_1: String,
    pub sector_2: String,
    pub sector_3: String,
    pub s1_best: String,
    pub s2_best: String,
    pub s3_best: String,
    pub elapsed: String,
}

/// Elm互換形式への変換関数
pub fn create_elm_compatible_output(
    event_name: &str,
    laps_with_metadata: &[LapWithMetadata],
    cars: &[Car],
) -> ElmCompatibleOutput {
    let raw_laps = convert_to_raw_laps(laps_with_metadata);
    let preprocessed_cars = convert_to_preprocessed_cars(cars);
    
    ElmCompatibleOutput {
        name: map_event_name(event_name).to_string(),
        laps: raw_laps,
        preprocessed: preprocessed_cars,
    }
}

/// LapWithMetadata から ElmRawLap への変換
fn convert_to_raw_laps(laps_with_metadata: &[LapWithMetadata]) -> Vec<ElmRawLap> {
    laps_with_metadata.iter().map(|lap_meta| {
        let lap = &lap_meta.lap;
        let meta = &lap_meta.metadata;
        
        ElmRawLap {
            car_number: lap.car_number.clone(),
            driver_number: lap_meta.csv_data.driver_number,
            lap_number: lap.lap,
            lap_time: duration::to_string(lap.time),
            lap_improvement: lap_meta.csv_data.lap_improvement,
            crossing_finish_line_in_pit: lap_meta.csv_data.crossing_finish_line_in_pit.clone(),
            s1: duration::to_string(lap.sector_1),
            s1_improvement: lap_meta.csv_data.s1_improvement,
            s2: duration::to_string(lap.sector_2),
            s2_improvement: lap_meta.csv_data.s2_improvement,
            s3: duration::to_string(lap.sector_3),
            s3_improvement: lap_meta.csv_data.s3_improvement,
            kph: lap_meta.csv_data.kph,
            elapsed: duration::to_string(lap.elapsed),
            hour: lap_meta.csv_data.hour.clone(),
            top_speed: lap_meta.csv_data.top_speed.clone().unwrap_or_default(),
            driver_name: lap.driver.clone(),
            pit_time: lap_meta.csv_data.pit_time.clone().unwrap_or_default(),
            class: meta.class.clone(),
            group: meta.group.clone(),
            team: meta.team.clone(),
            manufacturer: meta.manufacturer.clone(),
        }
    }).collect()
}

/// Car から ElmPreprocessedCar への変換
fn convert_to_preprocessed_cars(cars: &[Car]) -> Vec<ElmPreprocessedCar> {
    cars.iter().map(|car| {
        let drivers: Vec<ElmDriver> = car.meta_data.drivers.iter().map(|driver| {
            ElmDriver {
                name: driver.name.clone(),
                is_current_driver: driver.is_current_driver,
            }
        }).collect();
        
        let laps: Vec<ElmPreprocessedLap> = car.laps.iter().map(|lap| {
            ElmPreprocessedLap {
                car_number: lap.car_number.clone(),
                driver: lap.driver.clone(),
                lap: lap.lap,
                position: lap.position,
                time: duration::to_string(lap.time),
                best: duration::to_string(lap.best),
                sector_1: duration::to_string(lap.sector_1),
                sector_2: duration::to_string(lap.sector_2),
                sector_3: duration::to_string(lap.sector_3),
                s1_best: duration::to_string(lap.s1_best),
                s2_best: duration::to_string(lap.s2_best),
                s3_best: duration::to_string(lap.s3_best),
                elapsed: duration::to_string(lap.elapsed),
            }
        }).collect();
        
        let current_lap = car.current_lap.as_ref().map(|lap| {
            ElmPreprocessedLap {
                car_number: lap.car_number.clone(),
                driver: lap.driver.clone(),
                lap: lap.lap,
                position: lap.position,
                time: duration::to_string(lap.time),
                best: duration::to_string(lap.best),
                sector_1: duration::to_string(lap.sector_1),
                sector_2: duration::to_string(lap.sector_2),
                sector_3: duration::to_string(lap.sector_3),
                s1_best: duration::to_string(lap.s1_best),
                s2_best: duration::to_string(lap.s2_best),
                s3_best: duration::to_string(lap.s3_best),
                elapsed: duration::to_string(lap.elapsed),
            }
        });
        
        let last_lap = car.last_lap.as_ref().map(|lap| {
            ElmPreprocessedLap {
                car_number: lap.car_number.clone(),
                driver: lap.driver.clone(),
                lap: lap.lap,
                position: lap.position,
                time: duration::to_string(lap.time),
                best: duration::to_string(lap.best),
                sector_1: duration::to_string(lap.sector_1),
                sector_2: duration::to_string(lap.sector_2),
                sector_3: duration::to_string(lap.sector_3),
                s1_best: duration::to_string(lap.s1_best),
                s2_best: duration::to_string(lap.s2_best),
                s3_best: duration::to_string(lap.s3_best),
                elapsed: duration::to_string(lap.elapsed),
            }
        });
        
        ElmPreprocessedCar {
            car_number: car.meta_data.car_number.clone(),
            drivers,
            class: car.meta_data.class.to_string().to_string(), // Elm互換の文字列変換
            group: car.meta_data.group.clone(),
            team: car.meta_data.team.clone(),
            manufacturer: car.meta_data.manufacturer.clone(),
            start_position: car.start_position,
            laps,
            current_lap,
            last_lap,
        }
    }).collect()
}

/// Event name mapping (Elm Main.toEventName 互換)
pub fn map_event_name(event_id: &str) -> &str {
    match event_id {
        "qatar_1812km" => "Qatar 1812km",
        "imola_6h" => "6 Hours of Imola",
        "spa_6h" => "6 Hours of Spa",
        "le_mans_24h" => "24 Hours of Le Mans",
        "fuji_6h" => "6 Hours of Fuji",
        "bahrain_8h" => "8 Hours of Bahrain",
        "sao_paulo_6h" => "6 Hours of São Paulo",
        _ => "Encoding Error",
    }
}

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

/// メイン実行関数
pub fn run(config: Config) -> Result<(), Box<dyn Error>> {
    let csv_content = fs::read_to_string(&config.input_file)?;

    let laps_with_metadata = parse_laps_from_csv(&csv_content);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    println!("Read {} cars from CSV", cars.len());

    // Elm互換形式で出力
    let event_name = config.event_name.as_deref().unwrap_or("test_event");
    let elm_output = create_elm_compatible_output(event_name, &laps_with_metadata, &cars);
    let json = serde_json::to_string_pretty(&elm_output)?;

    let output_path = config.output_file.as_deref().unwrap_or("test.json");
    fs::File::create(output_path)
        .unwrap()
        .write_all(json.as_bytes())?;

    println!("Wrote Elm-compatible JSON to {}", output_path);
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
