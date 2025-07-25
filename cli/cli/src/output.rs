use serde::{Serialize, Serializer};
use motorsport::{Car, duration};

use crate::preprocess::LapWithMetadata;

/// Elm互換のKPH値（.0を除去して整数として表示）
fn serialize_kph_elm_compatible<S>(kph: &f32, serializer: S) -> Result<S::Ok, S::Error>
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

/// Elm互換のtopSpeed値（.0を除去して整数として表示）
fn serialize_top_speed_elm_compatible<S>(top_speed: &String, serializer: S) -> Result<S::Ok, S::Error>
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
    #[serde(serialize_with = "serialize_kph_elm_compatible")]
    pub kph: f32,
    pub elapsed: String,
    pub hour: String,
    #[serde(serialize_with = "serialize_top_speed_elm_compatible")]
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
            s1: if lap_meta.csv_data.s1_raw.is_empty() { String::new() } else { duration::to_string(lap.sector_1) },
            s1_improvement: lap_meta.csv_data.s1_improvement,
            s2: if lap_meta.csv_data.s2_raw.is_empty() { String::new() } else { duration::to_string(lap.sector_2) },
            s2_improvement: lap_meta.csv_data.s2_improvement,
            s3: if lap_meta.csv_data.s3_raw.is_empty() { String::new() } else { duration::to_string(lap.sector_3) },
            s3_improvement: lap_meta.csv_data.s3_improvement,
            kph: (lap_meta.csv_data.kph * 10.0).round() / 10.0,
            elapsed: duration::to_string(lap.elapsed),
            hour: lap_meta.csv_data.hour.clone(),
            top_speed: lap_meta.csv_data.top_speed.clone().unwrap_or_default(),
            driver_name: lap.driver.clone(),
            pit_time: lap_meta.csv_data.pit_time.map_or_else(String::new, |duration| duration::to_string(duration)),
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
        
        // Elm互換のためcurrent_lapとlast_lapをnullに設定
        let current_lap = None;
        let last_lap = None;
        
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_numeric_formatting_functions() {
        // 削除されたインテグレーションテストから移行された数値フォーマットテスト
        
        // KPH値のシリアライゼーションテスト
        let kph_integer: f32 = 186.0;
        let _kph_decimal: f32 = 184.3; // 将来的なテストケース用に保持
        
        // serialize_kph_elm_compatible関数の動作を間接的にテスト
        let test_lap = ElmRawLap {
            car_number: "007".to_string(),
            driver_number: 1,
            lap_number: 1,
            lap_time: "1:35.020".to_string(),
            lap_improvement: 0,
            crossing_finish_line_in_pit: "".to_string(),
            s1: "19.584".to_string(),
            s1_improvement: 0,
            s2: "31.338".to_string(),
            s2_improvement: 0,
            s3: "44.098".to_string(),
            s3_improvement: 0,
            kph: kph_integer,
            elapsed: "4:53.731".to_string(),
            hour: "13:06:19.241".to_string(),
            top_speed: "300.0".to_string(),
            driver_name: "Harry TINCKNELL".to_string(),
            pit_time: "".to_string(),
            class: "HYPERCAR".to_string(),
            group: "".to_string(),
            team: "Aston Martin Thor Team".to_string(),
            manufacturer: "Aston Martin".to_string(),
        };
        
        let json = serde_json::to_string(&test_lap).unwrap();
        
        // 186.0は186として出力される（整数）
        assert!(json.contains(r#""kph":186,"#) || json.contains(r#""kph": 186,"#));
        
        // topSpeed "300.0"は"300"として出力される
        assert!(json.contains(r#""topSpeed":"300","#) || json.contains(r#""topSpeed": "300","#));
    }

    #[test]
    fn test_top_speed_formatting_edge_cases() {
        // topSpeed値のフォーマット処理のエッジケーステスト
        
        let test_cases = vec![
            ("300.0", "300"),     // .0除去
            ("288.8", "288.8"),   // 小数点保持
            ("", ""),             // 空文字列保持
            ("invalid", "invalid"), // 不正値はそのまま
        ];
        
        for (input, expected) in test_cases {
            let test_lap = ElmRawLap {
                car_number: "007".to_string(),
                driver_number: 1,
                lap_number: 1,
                lap_time: "1:35.020".to_string(),
                lap_improvement: 0,
                crossing_finish_line_in_pit: "".to_string(),
                s1: "19.584".to_string(),
                s1_improvement: 0,
                s2: "31.338".to_string(),
                s2_improvement: 0,
                s3: "44.098".to_string(),
                s3_improvement: 0,
                kph: 186.0,
                elapsed: "4:53.731".to_string(),
                hour: "13:06:19.241".to_string(),
                top_speed: input.to_string(),
                driver_name: "Harry TINCKNELL".to_string(),
                pit_time: "".to_string(),
                class: "HYPERCAR".to_string(),
                group: "".to_string(),
                team: "Aston Martin Thor Team".to_string(),
                manufacturer: "Aston Martin".to_string(),
            };
            
            let json = serde_json::to_string(&test_lap).unwrap();
            let expected_json = format!(r#""topSpeed":"{}""#, expected);
            assert!(json.contains(&expected_json), 
                "Expected {} to be formatted as {}, but got: {}", input, expected, json);
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
}