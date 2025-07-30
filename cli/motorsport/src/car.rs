use serde::{Deserialize, Serialize};

use crate::lap::Lap;
use crate::{Class, Driver};

/// 車両情報（ElmのCar型と互換）
#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct Car {
    pub meta_data: MetaData,
    pub start_position: i32,
    pub laps: Vec<Lap>,
    pub current_lap: Option<Lap>,
    pub last_lap: Option<Lap>,
    pub status: Status,
}

impl Car {
    /// 新しい車両を作成
    pub fn new(meta_data: MetaData, start_position: i32, laps: Vec<Lap>) -> Self {
        Car {
            meta_data,
            start_position,
            laps,
            current_lap: None,
            last_lap: None,
            status: Status::PreRace,
        }
    }

    pub fn has_retired(&self) -> bool {
        self.status.has_retired()
    }

    pub fn set_status(&mut self, status: Status) {
        self.status = status;
    }
}

/// 車両メタデータ
#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
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

/// 車両のステータス
#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub enum Status {
    PreRace,
    Racing,
    Checkered,
    Retired,
}

impl Status {
    pub fn has_retired(&self) -> bool {
        matches!(self, Status::Retired)
    }

    pub fn to_string(&self) -> &'static str {
        match self {
            Status::PreRace => "Pre-Race",
            Status::Racing => "Racing",
            Status::Checkered => "Checkered",
            Status::Retired => "Retired",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_status_has_retired() {
        assert!(!Status::PreRace.has_retired());
        assert!(!Status::Racing.has_retired());
        assert!(!Status::Checkered.has_retired());
        assert!(Status::Retired.has_retired());
    }

    #[test]
    fn test_status_to_string() {
        assert_eq!(Status::PreRace.to_string(), "Pre-Race");
        assert_eq!(Status::Racing.to_string(), "Racing");
        assert_eq!(Status::Checkered.to_string(), "Checkered");
        assert_eq!(Status::Retired.to_string(), "Retired");
    }

    #[test]
    fn test_metadata_creation() {
        let drivers = vec![
            Driver::new("Will STEVENS".to_string(), false),
            Driver::new("Kamui KOBAYASHI".to_string(), true),
        ];

        let metadata = MetaData::new(
            "12".to_string(),
            drivers,
            Class::LMH,
            "H".to_string(),
            "Hertz Team JOTA".to_string(),
            "Porsche".to_string(),
        );

        assert_eq!(metadata.car_number, "12");
        assert_eq!(metadata.class, Class::LMH);
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
            Class::LMH,
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
        assert_eq!(car.meta_data.class, Class::LMH);
        assert_eq!(car.start_position, 3);
        assert_eq!(car.laps.len(), 2);
        assert_eq!(car.status, Status::PreRace);
        assert!(!car.has_retired());
    }

    #[test]
    fn test_car_json_serialization() {
        let drivers = vec![Driver::new("Will STEVENS".to_string(), true)];

        let metadata = MetaData::new(
            "12".to_string(),
            drivers,
            Class::LMH,
            "H".to_string(),
            "Hertz Team JOTA".to_string(),
            "Porsche".to_string(),
        );

        let car = Car::new(metadata, 1, vec![]);

        // JSONシリアライゼーションのテスト
        let json = serde_json::to_string(&car);
        assert!(json.is_ok());

        // JSONデシリアライゼーションのテスト
        let json_str = json.unwrap();
        let deserialized_car: Result<Car, _> = serde_json::from_str(&json_str);
        assert!(deserialized_car.is_ok());

        let deserialized = deserialized_car.unwrap();
        assert_eq!(deserialized.meta_data.car_number, car.meta_data.car_number);
        assert_eq!(deserialized.meta_data.team, car.meta_data.team);
        assert_eq!(deserialized.meta_data.class, car.meta_data.class);
        assert_eq!(deserialized.start_position, car.start_position);
        assert_eq!(deserialized.status, car.status);
    }
}
