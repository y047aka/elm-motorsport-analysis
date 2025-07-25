use std::collections::HashMap;
use serde::Deserialize;
use motorsport::{Lap, Car, MetaData, Class, Driver, duration};

/// CSV解析用の中間構造体
#[derive(Debug, Deserialize)]
struct LapCsvRow {
    #[serde(rename = "NUMBER", alias = " NUMBER")]
    car_number: String,
    #[serde(rename = "DRIVER_NUMBER", alias = " DRIVER_NUMBER")]
    #[allow(dead_code)]
    driver_number: u32,
    #[serde(rename = "DRIVER_NAME", alias = " DRIVER_NAME")]
    driver: String,
    #[serde(rename = "LAP_NUMBER", alias = " LAP_NUMBER")]
    lap: u32,
    #[serde(rename = "LAP_TIME", alias = " LAP_TIME")]
    lap_time: String,
    #[serde(rename = "LAP_IMPROVEMENT", alias = " LAP_IMPROVEMENT")]
    #[allow(dead_code)]
    lap_improvement: i32,
    #[serde(rename = "CROSSING_FINISH_LINE_IN_PIT", alias = " CROSSING_FINISH_LINE_IN_PIT")]
    #[allow(dead_code)]
    crossing_finish_line_in_pit: String,
    #[serde(rename = "S1", alias = " S1")]
    s1: String,
    #[serde(rename = "S1_IMPROVEMENT", alias = " S1_IMPROVEMENT")]
    #[allow(dead_code)]
    s1_improvement: i32,
    #[serde(rename = "S2", alias = " S2")]
    s2: String,
    #[serde(rename = "S2_IMPROVEMENT", alias = " S2_IMPROVEMENT")]
    #[allow(dead_code)]
    s2_improvement: i32,
    #[serde(rename = "S3", alias = " S3")]
    s3: String,
    #[serde(rename = "S3_IMPROVEMENT", alias = " S3_IMPROVEMENT")]
    #[allow(dead_code)]
    s3_improvement: i32,
    #[serde(rename = "KPH", alias = " KPH")]
    #[allow(dead_code)]
    kph: f32,
    #[serde(rename = "ELAPSED", alias = " ELAPSED")]
    elapsed: String,
    #[serde(rename = "HOUR", alias = " HOUR")]
    #[allow(dead_code)]
    hour: String,
    #[serde(rename = "TOP_SPEED", alias = " TOP_SPEED")]
    #[allow(dead_code)]
    top_speed: Option<String>,
    #[serde(rename = "PIT_TIME", alias = " PIT_TIME")]
    #[allow(dead_code)]
    pit_time: Option<String>,  // Raw string from CSV, will be converted to Duration
    #[serde(rename = "CLASS", alias = " CLASS")]
    class: String,
    #[serde(rename = "GROUP", alias = " GROUP")]
    group: String,
    #[serde(rename = "TEAM", alias = " TEAM")]
    team: String,
    #[serde(rename = "MANUFACTURER", alias = " MANUFACTURER")]
    manufacturer: String,
}

/// CSVからLapのリストを生成する
pub fn parse_laps_from_csv(csv: &str) -> Vec<LapWithMetadata> {
    csv::ReaderBuilder::new()
        .delimiter(b';')
        .from_reader(csv.as_bytes())
        .deserialize::<LapCsvRow>()
        .filter_map(|result| match result {
            Ok(row) => Some(convert_row_to_lap_with_metadata(row)),
            Err(e) => {
                eprintln!("Lap parse error: {e}");
                None
            }
        })
        .collect()
}

/// CSVの行データをLapWithMetadataに変換する純粋関数
fn convert_row_to_lap_with_metadata(row: LapCsvRow) -> LapWithMetadata {
    let time = duration::from_string(&row.lap_time).unwrap_or(0);
    let s1 = duration::from_string(&row.s1).unwrap_or(0);
    let s2 = duration::from_string(&row.s2).unwrap_or(0);
    let s3 = duration::from_string(&row.s3).unwrap_or(0);
    let elapsed = duration::from_string(&row.elapsed).unwrap_or(0);

    let lap = Lap::new(
        row.car_number,
        row.driver,
        row.lap,
        None,
        time,
        time,
        s1,
        s2,
        s3,
        s1,
        s2,
        s3,
        elapsed,
    );

    let metadata = CarMetadata {
        class: row.class,
        group: row.group,
        team: row.team,
        manufacturer: row.manufacturer,
    };

    let csv_data = CsvExtraData {
        driver_number: row.driver_number,
        lap_improvement: row.lap_improvement,
        crossing_finish_line_in_pit: row.crossing_finish_line_in_pit,
        s1_improvement: row.s1_improvement,
        s2_improvement: row.s2_improvement,
        s3_improvement: row.s3_improvement,
        kph: row.kph,
        hour: row.hour,
        top_speed: row.top_speed,
        pit_time: row.pit_time.as_ref().and_then(|s| duration::from_string(s)),
    };

    LapWithMetadata { lap, metadata, csv_data }
}

/// Lapとメタデータを組み合わせた構造体
#[derive(Debug, Clone)]
pub struct LapWithMetadata {
    pub lap: Lap,
    pub metadata: CarMetadata,
    pub csv_data: CsvExtraData,
}

/// CSVから取得した追加データ
#[derive(Debug, Clone)]
pub struct CsvExtraData {
    pub driver_number: u32,
    pub lap_improvement: i32,
    pub crossing_finish_line_in_pit: String,
    pub s1_improvement: i32,
    pub s2_improvement: i32,
    pub s3_improvement: i32,
    pub kph: f32,
    pub hour: String,
    pub top_speed: Option<String>,
    pub pit_time: Option<duration::Duration>,
}

/// 車両のメタデータ情報
#[derive(Debug, Clone)]
pub struct CarMetadata {
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
}

/// LapWithMetadataリストをCarごとにグループ化する
pub fn group_laps_by_car(laps_with_metadata: Vec<LapWithMetadata>) -> Vec<Car> {
    // インデックス付きグループ化でCSV出現順序を保持
    let mut car_data: HashMap<String, (Vec<Lap>, CarMetadata, Vec<String>)> = HashMap::new();
    let mut first_appearance: HashMap<String, usize> = HashMap::new();
    
    for (index, lap_with_meta) in laps_with_metadata.into_iter().enumerate() {
        let car_number = lap_with_meta.lap.car_number.clone();
        let driver_name = lap_with_meta.lap.driver.clone();
        
        // 最初の出現位置を記録
        first_appearance.entry(car_number.clone()).or_insert(index);
        
        // 車両データを蓄積
        car_data.entry(car_number)
            .and_modify(|(laps, _, drivers)| {
                laps.push(lap_with_meta.lap.clone());
                if !drivers.contains(&driver_name) {
                    drivers.push(driver_name.clone());
                }
            })
            .or_insert((
                vec![lap_with_meta.lap],
                lap_with_meta.metadata,
                vec![driver_name],
            ));
    }

    // 車両を作成し、最初の出現順序でソート
    let mut cars_with_index: Vec<(usize, Car)> = car_data
        .into_iter()
        .map(|(car_number, (laps, car_metadata, driver_names))| {
            let first_index = first_appearance[&car_number];
            let car = create_car_from_grouped_data(car_number, laps, car_metadata, driver_names);
            (first_index, car)
        })
        .collect();

    // CSVの出現順序でソート
    cars_with_index.sort_by_key(|(index, _)| *index);
    
    let mut cars: Vec<Car> = cars_with_index.into_iter().map(|(_, car)| car).collect();

    // 位置計算を実行
    calculate_positions(&mut cars);
    
    cars
}


/// グループ化されたデータからCarを作成する純粋関数
fn create_car_from_grouped_data(
    car_number: String,
    mut laps: Vec<Lap>,
    car_metadata: CarMetadata,
    driver_names: Vec<String>,
) -> Car {
    let drivers: Vec<Driver> = driver_names
        .into_iter()
        .enumerate()
        .map(|(i, name)| Driver::new(name, i == 0))
        .collect();

    let class = match car_metadata.class.as_str() {
        "HYPERCAR" => Class::LMH,
        "LMP2" => Class::LMP2,
        "LMGT3" => Class::LMGT3,
        _ => Class::LMH, // デフォルト
    };

    let meta = MetaData::new(
        car_number,
        drivers,
        class,
        car_metadata.group,
        car_metadata.team,
        car_metadata.manufacturer,
    );

    // ラップを番号順にソート
    laps.sort_by_key(|lap| lap.lap);

    // current_lapとlast_lapを決定
    let current_lap = laps.last().cloned();
    let last_lap = if laps.len() >= 2 {
        laps.get(laps.len() - 2).cloned()
    } else {
        None
    };

    // レース状況に応じてステータスを設定
    use motorsport::car::Status;
    
    let mut car = Car::new(meta, 1, laps);
    car.current_lap = current_lap;
    car.last_lap = last_lap;
    car.status = Status::Racing; // デフォルトはRacing
    
    car
}

/// 各車両の各ラップでの位置を計算する
fn calculate_positions(cars: &mut Vec<Car>) {
    if cars.is_empty() {
        return;
    }

    // スタートポジションを計算（1週目の経過時間順）
    calculate_start_positions(cars);

    // 最大ラップ数を取得
    let max_lap = cars.iter()
        .flat_map(|car| &car.laps)
        .map(|lap| lap.lap)
        .max()
        .unwrap_or(0);

    // 各ラップの位置を計算
    for lap_num in 1..=max_lap {
        calculate_position_for_lap(cars, lap_num);
    }
}

/// スタートポジションを計算（1週目の経過時間順）
fn calculate_start_positions(cars: &mut Vec<Car>) {
    // 1週目のラップを収集してソート
    let mut lap1_times: Vec<(String, u32)> = cars.iter()
        .filter_map(|car| {
            car.laps.iter()
                .find(|lap| lap.lap == 1)
                .map(|lap| (car.meta_data.car_number.clone(), lap.elapsed))
        })
        .collect();
    lap1_times.sort_by_key(|(_, elapsed)| *elapsed);

    // スタートポジションを設定
    for car in cars.iter_mut() {
        if let Some(position) = lap1_times.iter()
            .position(|(car_num, _)| car_num == &car.meta_data.car_number) {
            // Elm互換のため0-basedのindexをそのまま使用
            // 注意: 将来的には1-basedの position + 1 に変更する可能性がある
            car.start_position = position as i32;
        }
    }
}

/// 特定のラップでの各車両の位置を計算
fn calculate_position_for_lap(cars: &mut Vec<Car>, lap_num: u32) {
    // 指定されたラップでの各車両の経過時間を収集してソート
    let mut lap_times: Vec<(String, u32, usize)> = cars.iter()
        .enumerate()
        .filter_map(|(car_idx, car)| {
            car.laps.iter()
                .find(|l| l.lap == lap_num)
                .map(|lap| (car.meta_data.car_number.clone(), lap.elapsed, car_idx))
        })
        .collect();
    lap_times.sort_by_key(|(_, elapsed, _)| *elapsed);

    // 各車両のラップに位置を設定
    for (position, (car_number, _, car_idx)) in lap_times.iter().enumerate() {
        if let Some(car) = cars.get_mut(*car_idx) {
            if let Some(lap) = car.laps.iter_mut().find(|l| l.lap == lap_num && l.car_number == *car_number) {
                // Elm互換のため0-basedのindexをそのまま使用
                // 注意: 将来的には1-basedの position + 1 に変更する可能性がある
                lap.position = Some(position as u32);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_laps_from_csv() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;\n12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;\n7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.782;0:23.119;0:29.188;0:40.984;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.119;29.188;40.984;\n";
        let laps_with_metadata = parse_laps_from_csv(csv);
        assert_eq!(laps_with_metadata.len(), 2);
        assert_eq!(laps_with_metadata[0].lap.car_number, "12");
        assert_eq!(laps_with_metadata[0].lap.driver, "Will STEVENS");
        assert_eq!(laps_with_metadata[0].lap.lap, 1);
        assert_eq!(laps_with_metadata[0].metadata.team, "Hertz Team JOTA");
        assert_eq!(laps_with_metadata[0].metadata.manufacturer, "Porsche");
        assert_eq!(laps_with_metadata[1].lap.car_number, "7");
        assert_eq!(laps_with_metadata[1].lap.driver, "Kamui KOBAYASHI");
        assert_eq!(laps_with_metadata[1].lap.lap, 1);
        assert_eq!(laps_with_metadata[1].metadata.team, "Toyota Gazoo Racing");
        assert_eq!(laps_with_metadata[1].metadata.manufacturer, "Toyota");
    }

    #[test]
    fn test_group_laps_by_car() {
        let laps_with_metadata = vec![
            LapWithMetadata {
                lap: Lap::new(
                    "12".to_string(), "Will STEVENS".to_string(), 1, Some(3), 95365, 95365, 23155, 29928, 42282, 23155, 29928, 42282, 95365
                ),
                metadata: CarMetadata {
                    class: "HYPERCAR".to_string(),
                    group: "H".to_string(),
                    team: "Hertz Team JOTA".to_string(),
                    manufacturer: "Porsche".to_string(),
                },
                csv_data: CsvExtraData {
                    driver_number: 1,
                    lap_improvement: 0,
                    crossing_finish_line_in_pit: String::new(),
                    s1_improvement: 0,
                    s2_improvement: 0,
                    s3_improvement: 0,
                    kph: 160.7,
                    hour: "11:02:02.856".to_string(),
                    top_speed: None,
                    pit_time: None,
                },
            },
            LapWithMetadata {
                lap: Lap::new(
                    "12".to_string(), "Robin FRIJNS".to_string(), 2, Some(2), 113610, 95365, 23155, 29928, 42282, 23155, 29928, 42282, 113610
                ),
                metadata: CarMetadata {
                    class: "HYPERCAR".to_string(),
                    group: "H".to_string(),
                    team: "Hertz Team JOTA".to_string(),
                    manufacturer: "Porsche".to_string(),
                },
                csv_data: CsvExtraData {
                    driver_number: 2,
                    lap_improvement: 1,
                    crossing_finish_line_in_pit: String::new(),
                    s1_improvement: 1,
                    s2_improvement: 1,
                    s3_improvement: 1,
                    kph: 165.2,
                    hour: "11:03:35.101".to_string(),
                    top_speed: Some("298.6".to_string()),
                    pit_time: None,
                },
            },
            LapWithMetadata {
                lap: Lap::new(
                    "7".to_string(), "Kamui KOBAYASHI".to_string(), 1, Some(1), 93291, 93291, 23119, 29188, 40984, 23119, 29188, 40984, 93291
                ),
                metadata: CarMetadata {
                    class: "HYPERCAR".to_string(),
                    group: "H".to_string(),
                    team: "Toyota Gazoo Racing".to_string(),
                    manufacturer: "Toyota".to_string(),
                },
                csv_data: CsvExtraData {
                    driver_number: 1,
                    lap_improvement: 0,
                    crossing_finish_line_in_pit: String::new(),
                    s1_improvement: 0,
                    s2_improvement: 0,
                    s3_improvement: 0,
                    kph: 175.0,
                    hour: "11:02:00.782".to_string(),
                    top_speed: Some("298.6".to_string()),
                    pit_time: None,
                },
            },
        ];
        let cars = group_laps_by_car(laps_with_metadata);
        assert_eq!(cars.len(), 2);

        let car12 = cars.iter().find(|c| c.meta_data.car_number == "12").unwrap();
        assert_eq!(car12.laps.len(), 2);
        assert_eq!(car12.meta_data.team, "Hertz Team JOTA");
        assert_eq!(car12.meta_data.manufacturer, "Porsche");
        assert_eq!(car12.meta_data.drivers.len(), 2); // 2人のドライバー

        let car7 = cars.iter().find(|c| c.meta_data.car_number == "7").unwrap();
        assert_eq!(car7.laps.len(), 1);
        assert_eq!(car7.meta_data.team, "Toyota Gazoo Racing");
        assert_eq!(car7.meta_data.manufacturer, "Toyota");
        assert_eq!(car7.meta_data.drivers.len(), 1); // 1人のドライバー
    }
}
