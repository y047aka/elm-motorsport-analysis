use motorsport::{Car, TimelineEvent, calc_time_limit, calc_timeline_events, car, duration};
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

/// メタデータ出力データ構造（name, startingGrid, timelineEvents）
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MetadataOutput {
    pub name: String,
    pub starting_grid: Vec<StartingGrid>,
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

/// Starting grid entry format (startingGrid配列の要素)
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StartingGrid {
    pub position: i32,
    pub car: car::MetaData,
}

/// メタデータ出力データ作成関数（name, startingGrid, timelineEvents）
pub fn create_metadata_output(event_name: &str, cars: &[Car]) -> MetadataOutput {
    let starting_grid = starting_grid_from(cars);

    // タイムラインイベントを計算
    let time_limit = calc_time_limit(cars);
    let timeline_events = calc_timeline_events(time_limit, cars);

    MetadataOutput {
        name: map_event_name(event_name).to_string(),
        starting_grid,
        timeline_events,
    }
}

/// ラップデータ出力データ作成関数（lapsのみ）
pub fn create_laps_output(laps_with_metadata: &[LapWithMetadata]) -> Vec<RawLap> {
    raw_laps_from(laps_with_metadata)
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

/// Car から StartingGrid への変換
fn starting_grid_from(cars: &[Car]) -> Vec<StartingGrid> {
    cars.iter()
        .map(|car| StartingGrid {
            position: car.start_position,
            car: car.meta_data.clone(),
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
        "cota_6h" => "Lone Star Le Mans",
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
        assert_eq!(map_event_name("cota_6h"), "Lone Star Le Mans");
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
            Class::HYPERCAR,
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

        // create_metadata_output関数でtimeline_eventsが含まれることをテスト
        let output = create_metadata_output("test_event", &cars);

        // timeline_eventsフィールドが存在することを確認
        assert!(!output.timeline_events.is_empty());

        // 最初のイベントはレーススタートである
        assert_eq!(output.timeline_events[0].event_time, 0);
        assert_eq!(
            output.timeline_events[0].event_type,
            motorsport::EventType::RaceStart
        );
    }

    #[test]
    fn test_create_output_includes_starting_grid() {
        use motorsport::{Car, Class, Driver, Lap, MetaData};

        // テスト用の車両データを作成
        let drivers = vec![Driver::new("Test Driver".to_string(), false)];
        let metadata = MetaData::new(
            "1".to_string(),
            drivers,
            Class::HYPERCAR,
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

        // create_metadata_output関数でstarting_gridが含まれることをテスト
        let output = create_metadata_output("test_event", &cars);

        // starting_gridフィールドが存在することを確認
        assert_eq!(output.starting_grid.len(), 1);

        // starting_gridの構造を確認
        let grid_entry = &output.starting_grid[0];
        assert_eq!(grid_entry.position, 1);
        assert_eq!(grid_entry.car.car_number, "1");
        assert_eq!(grid_entry.car.team, "Test Team");
        assert_eq!(grid_entry.car.manufacturer, "Test Manufacturer");
    }
}
