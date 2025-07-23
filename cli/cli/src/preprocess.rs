use std::collections::HashMap;
use serde::Deserialize;
use motorsport::{Lap, Car, MetaData, Class, Driver, duration};

/// CSV解析用の中間構造体
#[derive(Debug, Deserialize)]
struct LapCsvRow {
    #[serde(rename = "NUMBER")]
    car_number: String,
    #[serde(rename = "DRIVER_NAME")]
    driver: String,
    #[serde(rename = "LAP_NUMBER")]
    lap: u32,
    #[serde(rename = "LAP_TIME")]
    lap_time: String,
    #[serde(rename = "S1")]
    s1: String,
    #[serde(rename = "S2")]
    s2: String,
    #[serde(rename = "S3")]
    s3: String,
    #[serde(rename = "ELAPSED")]
    elapsed: String,
    #[serde(rename = "CLASS")]
    class: String,
    #[serde(rename = "GROUP")]
    group: String,
    #[serde(rename = "TEAM")]
    team: String,
    #[serde(rename = "MANUFACTURER")]
    manufacturer: String,
}

/// CSVからLapのリストを生成する
pub fn parse_laps_from_csv(csv: &str) -> Vec<LapWithMetadata> {
    let mut reader = csv::ReaderBuilder::new()
        .delimiter(b';')
        .from_reader(csv.as_bytes());
    let mut laps = Vec::new();
    for result in reader.deserialize() {
        match result {
            Ok(row) => {
                let row: LapCsvRow = row;
                let time = duration::from_string(&row.lap_time).unwrap_or(0);
                let s1 = duration::from_string(&row.s1).unwrap_or(0);
                let s2 = duration::from_string(&row.s2).unwrap_or(0);
                let s3 = duration::from_string(&row.s3).unwrap_or(0);
                let elapsed = duration::from_string(&row.elapsed).unwrap_or(0);

                let lap = Lap::new(
                    row.car_number.clone(),
                    row.driver.clone(),
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

                laps.push(LapWithMetadata { lap, metadata });
            }
            Err(e) => {
                eprintln!("Lap parse error: {e}");
            }
        }
    }
    laps
}

/// Lapとメタデータを組み合わせた構造体
#[derive(Debug, Clone)]
pub struct LapWithMetadata {
    pub lap: Lap,
    pub metadata: CarMetadata,
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
    let mut car_map: HashMap<String, (Vec<Lap>, CarMetadata, Vec<String>)> = HashMap::new();

    for lap_with_meta in laps_with_metadata {
        let car_number = lap_with_meta.lap.car_number.clone();
        let driver_name = lap_with_meta.lap.driver.clone();

        let entry = car_map.entry(car_number).or_insert((
            Vec::new(),
            lap_with_meta.metadata.clone(),
            Vec::new(),
        ));

        entry.0.push(lap_with_meta.lap);

        // ドライバーが既にリストにない場合は追加
        if !entry.2.contains(&driver_name) {
            entry.2.push(driver_name);
        }
    }

    // 実際のメタデータを使用してCarを生成
    car_map.into_iter()
        .map(|(car_number, (laps, car_metadata, driver_names))| {
            // ドライバーリストを作成（最後のドライバーを現在のドライバーとする）
            let drivers: Vec<Driver> = driver_names.into_iter().enumerate()
                .map(|(i, name)| Driver::new(name, i == 0)) // 最初のドライバーを現在のドライバーとする
                .collect();

            // CLASSフィールドからClass enumに変換
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

            Car::new(meta, 0, laps)
        })
        .collect()
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
