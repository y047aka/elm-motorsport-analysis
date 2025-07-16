use std::collections::HashMap;

use crate::{Car, Class, Driver, Lap, MetaData};

/// CSVからLapのリストを生成する（仮: 実装は後で）
pub fn parse_laps_from_csv(_csv: &str) -> Vec<Lap> {
    // TODO: 実装
    vec![]
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
            let meta = MetaData {
                car_number: car_number.clone(),
                drivers: vec![Driver { name: "Dummy".to_string(), is_current_driver: true }],
                class: Class::LMH,
                group: "H".to_string(),
                team: "Dummy Team".to_string(),
                manufacturer: "Dummy".to_string(),
            };
            Car::new(meta, 0, laps)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

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
