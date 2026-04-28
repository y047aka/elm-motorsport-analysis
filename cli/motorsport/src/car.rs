use serde::Serialize;

use crate::lap::Lap;
use crate::{Class, Driver};

/// 車両情報（ElmのCar型と互換）
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Car {
    pub meta_data: MetaData,
    pub start_position: i32,
    pub laps: Vec<Lap>,
}

impl Car {
    /// 新しい車両を作成
    pub fn new(meta_data: MetaData, start_position: i32, laps: Vec<Lap>) -> Self {
        Car {
            meta_data,
            start_position,
            laps,
        }
    }
}

/// 車両メタデータ
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MetaData {
    pub car_number: CarNumber,
    pub drivers: Vec<Driver>,
    pub class: Class,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
}

impl MetaData {
    pub fn new(
        car_number: CarNumber,
        drivers: Vec<Driver>,
        class: Class,
        group: String,
        team: String,
        manufacturer: String,
    ) -> Self {
        MetaData {
            car_number,
            drivers,
            class,
            group,
            team,
            manufacturer,
        }
    }
}

/// 車両番号の型エイリアス
pub type CarNumber = String;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_metadata_creation() {
        let drivers = vec![
            Driver::new("Will STEVENS".to_string(), false),
            Driver::new("Kamui KOBAYASHI".to_string(), true),
        ];

        let metadata = MetaData::new(
            "12".to_string(),
            drivers,
            Class::HYPERCAR,
            "H".to_string(),
            "Hertz Team JOTA".to_string(),
            "Porsche".to_string(),
        );

        assert_eq!(metadata.car_number, "12");
        assert_eq!(metadata.class, Class::HYPERCAR);
        assert_eq!(metadata.group, "H");
        assert_eq!(metadata.team, "Hertz Team JOTA");
        assert_eq!(metadata.manufacturer, "Porsche");
        assert_eq!(metadata.drivers.len(), 2);
    }

    #[test]
    fn test_car_creation() {
        let drivers = vec![
            Driver::new("Will STEVENS".to_string(), false),
            Driver::new("Kamui KOBAYASHI".to_string(), true),
        ];

        let metadata = MetaData::new(
            "12".to_string(),
            drivers,
            Class::HYPERCAR,
            "H".to_string(),
            "Hertz Team JOTA".to_string(),
            "Porsche".to_string(),
        );

        let laps = vec![
            Lap::new(
                "12".to_string(),
                "Will STEVENS".to_string(),
                1,
                Some(3),
                95365,
                95365,
                23155,
                29928,
                42282,
                23155,
                29928,
                42282,
                95365,
            ),
            Lap::new(
                "12".to_string(),
                "Kamui KOBAYASHI".to_string(),
                2,
                Some(2),
                113610,
                95365,
                23155,
                29928,
                42282,
                23155,
                29928,
                42282,
                113610,
            ),
        ];

        let car = Car::new(metadata, 3, laps);

        assert_eq!(car.meta_data.car_number, "12");
        assert_eq!(car.meta_data.team, "Hertz Team JOTA");
        assert_eq!(car.meta_data.class, Class::HYPERCAR);
        assert_eq!(car.start_position, 3);
        assert_eq!(car.laps.len(), 2);
    }

    #[test]
    fn test_car_json_serialization() {
        let drivers = vec![Driver::new("Will STEVENS".to_string(), true)];

        let metadata = MetaData::new(
            "12".to_string(),
            drivers,
            Class::HYPERCAR,
            "H".to_string(),
            "Hertz Team JOTA".to_string(),
            "Porsche".to_string(),
        );

        let car = Car::new(metadata, 1, vec![]);

        let json = serde_json::to_string(&car).unwrap();
        assert!(json.contains("\"carNumber\":\"12\""));
        assert!(json.contains("\"team\":\"Hertz Team JOTA\""));
        assert!(json.contains("\"manufacturer\":\"Porsche\""));
        assert!(json.contains("\"start_position\":1"));
    }
}
