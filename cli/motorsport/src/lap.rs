use crate::{Duration, duration};
use serde::{Deserialize, Deserializer, Serialize, Serializer};

fn serialize_duration<S>(duration: &Duration, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let formatted_duration = duration::to_string(*duration);
    serializer.serialize_str(&formatted_duration)
}

fn deserialize_duration<'de, D>(deserializer: D) -> Result<Duration, D::Error>
where
    D: Deserializer<'de>,
{
    let s = String::deserialize(deserializer)?;
    duration::from_string(&s).ok_or_else(|| serde::de::Error::custom("Invalid duration format"))
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Lap {
    pub car_number: String,
    pub driver: String,
    pub lap: u32,
    pub position: Option<u32>,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub time: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub best: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub sector_1: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub sector_2: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub sector_3: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub s1_best: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub s2_best: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub s3_best: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub elapsed: Duration,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "miniSectors")]
    pub mini_sectors: Option<MiniSectors>,
}

impl Lap {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        car_number: String,
        driver: String,
        lap: u32,
        position: Option<u32>,
        time: Duration,
        best: Duration,
        sector_1: Duration,
        sector_2: Duration,
        sector_3: Duration,
        s1_best: Duration,
        s2_best: Duration,
        s3_best: Duration,
        elapsed: Duration,
    ) -> Self {
        Lap {
            car_number,
            driver,
            lap,
            position,
            time,
            best,
            sector_1,
            sector_2,
            sector_3,
            s1_best,
            s2_best,
            s3_best,
            elapsed,
            mini_sectors: None,
        }
    }

    /// ミニセクター情報を設定した新しいLapを作成
    #[allow(clippy::too_many_arguments)]
    pub fn new_with_mini_sectors(
        car_number: String,
        driver: String,
        lap: u32,
        position: Option<u32>,
        time: Duration,
        best: Duration,
        sector_1: Duration,
        sector_2: Duration,
        sector_3: Duration,
        s1_best: Duration,
        s2_best: Duration,
        s3_best: Duration,
        elapsed: Duration,
        mini_sectors: Option<MiniSectors>,
    ) -> Self {
        Lap {
            car_number,
            driver,
            lap,
            position,
            time,
            best,
            sector_1,
            sector_2,
            sector_3,
            s1_best,
            s2_best,
            s3_best,
            elapsed,
            mini_sectors,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MiniSector {
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub time: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub elapsed: Duration,
    #[serde(
        serialize_with = "serialize_duration",
        deserialize_with = "deserialize_duration"
    )]
    pub best: Duration,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MiniSectors {
    pub scl2: MiniSector,
    pub z4: MiniSector,
    pub ip1: MiniSector,
    pub z12: MiniSector,
    pub sclc: MiniSector,
    pub a7_1: MiniSector,
    pub ip2: MiniSector,
    pub a8_1: MiniSector,
    pub sclb: MiniSector,
    pub porin: MiniSector,
    pub porout: MiniSector,
    pub pitref: MiniSector,
    pub scl1: MiniSector,
    pub fordout: MiniSector,
    pub fl: MiniSector,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lap_json_serialization() {
        let lap = Lap::new(
            "7".to_string(),
            "Kamui KOBAYASHI".to_string(),
            2,
            None,
            93291,
            93291,
            23119,
            29188,
            40984,
            23119,
            29188,
            40984,
            93291,
        );
        let json = serde_json::to_string(&lap);
        assert!(json.is_ok());
        let json_str = json.unwrap();
        let deserialized: Lap = serde_json::from_str(&json_str).unwrap();
        assert_eq!(deserialized.position, None);
        assert_eq!(deserialized, lap);
    }
}
