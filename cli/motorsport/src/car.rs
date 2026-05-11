use serde::Serialize;

use crate::Driver;

/// 車両メタデータ（FlixのMotorsport.Car.Carと互換）
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MetaData {
    pub car_number: CarNumber,
    pub drivers: Vec<Driver>,
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
}

impl MetaData {
    pub fn new(
        car_number: CarNumber,
        drivers: Vec<Driver>,
        class: String,
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
            Driver::new("Will STEVENS".to_string()),
            Driver::new("Kamui KOBAYASHI".to_string()),
        ];

        let metadata = MetaData::new(
            "12".to_string(),
            drivers,
            "HYPERCAR".to_string(),
            "H".to_string(),
            "Hertz Team JOTA".to_string(),
            "Porsche".to_string(),
        );

        assert_eq!(metadata.car_number, "12");
        assert_eq!(metadata.class, "HYPERCAR");
        assert_eq!(metadata.group, "H");
        assert_eq!(metadata.team, "Hertz Team JOTA");
        assert_eq!(metadata.manufacturer, "Porsche");
        assert_eq!(metadata.drivers.len(), 2);
    }

    #[test]
    fn test_metadata_json_serialization() {
        let drivers = vec![Driver::new("Will STEVENS".to_string())];

        let metadata = MetaData::new(
            "12".to_string(),
            drivers,
            "HYPERCAR".to_string(),
            "H".to_string(),
            "Hertz Team JOTA".to_string(),
            "Porsche".to_string(),
        );

        let json = serde_json::to_string(&metadata).unwrap();
        assert!(json.contains("\"carNumber\":\"12\""));
        assert!(json.contains("\"class\":\"HYPERCAR\""));
        assert!(json.contains("\"team\":\"Hertz Team JOTA\""));
        assert!(json.contains("\"manufacturer\":\"Porsche\""));
    }
}
