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
}

/// CSVからLapのリストを生成する
pub fn parse_laps_from_csv(csv: &str) -> Vec<Lap> {
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
                laps.push(Lap::new(
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
                ));
            }
            Err(e) => {
                eprintln!("Lap parse error: {e}");
            }
        }
    }
    laps
}

/// LapリストをCarごとにグループ化する
pub fn group_laps_by_car(laps: Vec<Lap>) -> Vec<Car> {
    let mut map: HashMap<String, Vec<Lap>> = HashMap::new();
    for lap in laps {
        map.entry(lap.car_number.clone()).or_default().push(lap);
    }
    // 仮のMetaData/DriverでCarを生成
    map.into_iter()
        .map(|(car_number, laps)| {
            let meta = MetaData::new(
                car_number.clone(),
                vec![Driver::new("Dummy".to_string(), true)],
                Class::LMH,
                "H".to_string(),
                "Dummy Team".to_string(),
                "Dummy".to_string(),
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
        let laps = parse_laps_from_csv(csv);
        assert_eq!(laps.len(), 2);
        assert_eq!(laps[0].car_number, "12");
        assert_eq!(laps[0].driver, "Will STEVENS");
        assert_eq!(laps[0].lap, 1);
        assert_eq!(laps[1].car_number, "7");
        assert_eq!(laps[1].driver, "Kamui KOBAYASHI");
        assert_eq!(laps[1].lap, 1);
    }

    #[test]
    fn test_group_laps_by_car() {
        let laps = vec![
            Lap::new(
                "12".to_string(), "Will STEVENS".to_string(), 1, Some(3), 95365, 95365, 23155, 29928, 42282, 23155, 29928, 42282, 95365
            ),
            Lap::new(
                "12".to_string(), "Will STEVENS".to_string(), 2, Some(2), 113610, 95365, 23155, 29928, 42282, 23155, 29928, 42282, 113610
            ),
            Lap::new(
                "7".to_string(), "Kamui KOBAYASHI".to_string(), 1, Some(1), 93291, 93291, 23119, 29188, 40984, 23119, 29188, 40984, 93291
            ),
        ];
        let cars = group_laps_by_car(laps);
        assert_eq!(cars.len(), 2);
        let car12 = cars.iter().find(|c| c.meta_data.car_number == "12").unwrap();
        assert_eq!(car12.laps.len(), 2);
        let car7 = cars.iter().find(|c| c.meta_data.car_number == "7").unwrap();
        assert_eq!(car7.laps.len(), 1);
    }
}
