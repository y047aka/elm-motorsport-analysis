use motorsport::{Car, Driver, TimelineEvent, calc_time_limit, calc_timeline_events, duration};
use serde::{Serialize, Serializer};

use crate::preprocess::LapWithMetadata;

/// セクタータイムのフォーマット
fn format_sector_time(raw_time: &str, sector_duration: u32) -> String {
    if raw_time.is_empty() {
        String::new()
    } else {
        duration::to_string(sector_duration)
    }
}

/// KPH値のシリアライゼーション（.0を除去して整数として表示）
fn serialize_speed<S>(kph: &f32, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    // .0の場合は整数として出力、それ以外は元のf32として出力
    if kph.fract() == 0.0 {
        serializer.serialize_i32(*kph as i32)
    } else {
        serializer.serialize_f32(*kph)
    }
}

/// TopSpeed値のシリアライゼーション（.0を除去して整数として表示）
fn serialize_top_speed<S>(top_speed: &str, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    // 空文字列の場合はそのまま文字列として出力
    if top_speed.is_empty() {
        return serializer.serialize_str(top_speed);
    }

    // 数値として解析を試行
    if let Ok(speed) = top_speed.parse::<f32>() {
        // .0の場合は整数文字列として出力、それ以外は元の文字列として出力
        if speed.fract() == 0.0 {
            serializer.serialize_str(&format!("{}", speed as i32))
        } else {
            serializer.serialize_str(top_speed)
        }
    } else {
        // 解析できない場合は元の文字列をそのまま出力
        serializer.serialize_str(top_speed)
    }
}

/// 3層出力データ構造
#[derive(Debug, Serialize)]
pub struct Output {
    pub name: String,
    pub laps: Vec<RawLap>,
    pub preprocessed: Vec<PreprocessedCar>,
    pub timeline_events: Vec<TimelineEvent>,
}

/// Raw lap data format (laps配列の要素)
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RawLap {
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
    #[serde(serialize_with = "serialize_speed")]
    pub kph: f32,
    pub elapsed: String,
    pub hour: String,
    #[serde(serialize_with = "serialize_top_speed")]
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
pub struct PreprocessedCar {
    pub car_number: String,
    pub drivers: Vec<Driver>,
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
    pub start_position: i32,
    pub laps: Vec<PreprocessedLap>,
    pub current_lap: Option<PreprocessedLap>,
    pub last_lap: Option<PreprocessedLap>,
}

/// Preprocessed lap format (車両内のlaps配列の要素)
#[derive(Debug, Serialize)]
pub struct PreprocessedLap {
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

/// 出力データ作成関数
pub fn create_output(
    event_name: &str,
    laps_with_metadata: &[LapWithMetadata],
    cars: &[Car],
) -> Output {
    let raw_laps = raw_laps_from(laps_with_metadata);
    let preprocessed_cars = preprocessed_cars_from(cars);

    // タイムラインイベントを計算
    let time_limit = calc_time_limit(cars);
    let timeline_events = calc_timeline_events(time_limit, cars);

    Output {
        name: map_event_name(event_name).to_string(),
        laps: raw_laps,
        preprocessed: preprocessed_cars,
        timeline_events,
    }
}

/// LapWithMetadata から RawLap への変換
fn raw_laps_from(laps_with_metadata: &[LapWithMetadata]) -> Vec<RawLap> {
    laps_with_metadata
        .iter()
        .map(|lap_meta| {
            let lap = &lap_meta.lap;
            let meta = &lap_meta.metadata;

            RawLap {
                car_number: lap.car_number.clone(),
                driver_number: lap_meta.csv_data.driver_number,
                lap_number: lap.lap,
                lap_time: duration::to_string(lap.time),
                lap_improvement: lap_meta.csv_data.lap_improvement,
                crossing_finish_line_in_pit: lap_meta.csv_data.crossing_finish_line_in_pit.clone(),
                s1: format_sector_time(&lap_meta.csv_data.s1_raw, lap.sector_1),
                s1_improvement: lap_meta.csv_data.s1_improvement,
                s2: format_sector_time(&lap_meta.csv_data.s2_raw, lap.sector_2),
                s2_improvement: lap_meta.csv_data.s2_improvement,
                s3: format_sector_time(&lap_meta.csv_data.s3_raw, lap.sector_3),
                s3_improvement: lap_meta.csv_data.s3_improvement,
                kph: (lap_meta.csv_data.kph * 10.0).round() / 10.0,
                elapsed: duration::to_string(lap.elapsed),
                hour: lap_meta.csv_data.hour.clone(),
                top_speed: lap_meta.csv_data.top_speed.clone().unwrap_or_default(),
                driver_name: lap.driver.clone(),
                pit_time: lap_meta
                    .csv_data
                    .pit_time
                    .map_or_else(String::new, duration::to_string),
                class: meta.class.clone(),
                group: meta.group.clone(),
                team: meta.team.clone(),
                manufacturer: meta.manufacturer.clone(),
            }
        })
        .collect()
}

/// Car から PreprocessedCar への変換
fn preprocessed_cars_from(cars: &[Car]) -> Vec<PreprocessedCar> {
    cars.iter()
        .map(|car| {
            let drivers = car.meta_data.drivers.clone();

            PreprocessedCar {
                car_number: car.meta_data.car_number.clone(),
                drivers,
                class: car.meta_data.class.to_string().to_string(),
                group: car.meta_data.group.clone(),
                team: car.meta_data.team.clone(),
                manufacturer: car.meta_data.manufacturer.clone(),
                start_position: car.start_position,
                laps: vec![],
                current_lap: None,
                last_lap: None,
            }
        })
        .collect()
}

/// Event name mapping
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_serialize_speed() {
        use serde_json::Value;

        // 整数値: .0を除去
        let result = serialize_speed(&186.0, serde_json::value::Serializer).unwrap();
        assert_eq!(result, Value::Number(186.into()));

        // 小数値: そのまま保持
        let result = serialize_speed(&184.3, serde_json::value::Serializer).unwrap();
        if let Value::Number(n) = result {
            assert!((n.as_f64().unwrap() - 184.3).abs() < 0.001);
        } else {
            panic!("Expected number, got {result:?}");
        }
    }

    #[test]
    fn test_serialize_top_speed() {
        use serde_json::value::Serializer;

        let test_cases = vec![
            ("300.0", "300"),       // .0除去
            ("288.8", "288.8"),     // 小数点保持
            ("", ""),               // 空文字列保持
            ("invalid", "invalid"), // 不正値はそのまま
        ];

        for (input, expected) in test_cases {
            let result = serialize_top_speed(input, Serializer).unwrap();
            assert_eq!(
                result,
                serde_json::Value::String(expected.to_string()),
                "Expected '{input}' to be formatted as '{expected}', but got: {result:?}"
            );
        }
    }

    #[test]
    fn test_event_name_mapping() {
        // イベント名マッピングのテスト（削除されたテストから移行）
        assert_eq!(map_event_name("qatar_1812km"), "Qatar 1812km");
        assert_eq!(map_event_name("imola_6h"), "6 Hours of Imola");
        assert_eq!(map_event_name("spa_6h"), "6 Hours of Spa");
        assert_eq!(map_event_name("le_mans_24h"), "24 Hours of Le Mans");
        assert_eq!(map_event_name("fuji_6h"), "6 Hours of Fuji");
        assert_eq!(map_event_name("bahrain_8h"), "8 Hours of Bahrain");
        assert_eq!(map_event_name("sao_paulo_6h"), "6 Hours of São Paulo");
        assert_eq!(map_event_name("unknown_event"), "Encoding Error");
    }

    #[test]
    fn test_create_output_includes_timeline_events() {
        use motorsport::{Car, Class, Driver, Lap, MetaData};

        // テスト用の車両データを作成
        let drivers = vec![Driver::new("Test Driver".to_string(), false)];
        let metadata = MetaData::new(
            "1".to_string(),
            drivers,
            Class::LMH,
            "H".to_string(),
            "Test Team".to_string(),
            "Test Manufacturer".to_string(),
        );

        let laps = vec![Lap::new(
            "1".to_string(),
            "Test Driver".to_string(),
            1,
            Some(1),
            95365,
            95365,
            23155,
            29928,
            42282,
            23155,
            29928,
            42282,
            95365,
        )];

        let car = Car::new(metadata, 1, laps);
        let cars = vec![car];

        // create_output関数でtimeline_eventsが含まれることをテスト
        let output = create_output("test_event", &[], &cars);

        // timeline_eventsフィールドが存在することを確認
        assert!(!output.timeline_events.is_empty());

        // 最初のイベントはレーススタートである
        assert_eq!(output.timeline_events[0].event_time, 0);
        assert_eq!(
            output.timeline_events[0].event_type,
            motorsport::EventType::RaceStart
        );
    }
}
