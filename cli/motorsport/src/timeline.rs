use crate::car::CarNumber;
use crate::lap::Lap;
use crate::{Duration, duration};
use serde::{Deserialize, Serialize, Serializer};

/// タイムラインイベント（レース中の時刻ベースのイベント）
#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct TimelineEvent {
    #[serde(serialize_with = "serialize_event_time")]
    pub event_time: Duration,
    pub event_type: EventType,
}

/// event_timeをduration::to_stringを使って整形してシリアライズする
fn serialize_event_time<S>(event_time: &Duration, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let formatted_time = duration::to_string(*event_time);
    serializer.serialize_str(&formatted_time)
}

/// durationをduration::to_stringを使って整形してシリアライズする
fn serialize_duration<S>(duration: &Duration, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let formatted_duration = duration::to_string(*duration);
    serializer.serialize_str(&formatted_duration)
}

/// イベントタイプ
#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub enum EventType {
    RaceStart,
    CarEvent(CarNumber, CarEventType),
}

/// ピットインイベントの詳細データ
#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct PitInEvent {
    pub lap_number: u32,
    #[serde(serialize_with = "serialize_duration")]
    pub duration: Duration,
}

/// ピットアウトイベントの詳細データ
#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct PitOutEvent {
    pub lap_number: u32,
    #[serde(serialize_with = "serialize_duration")]
    pub duration: Duration,
}

/// 車両イベントタイプ
#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub enum CarEventType {
    Start { current_lap: Lap },
    LapCompleted { lap_number: u32, next_lap: Lap },
    PitIn(PitInEvent),
    PitOut(PitOutEvent),
    Retirement,
    Checkered,
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_timeline_event_creation() {
        let event = TimelineEvent {
            event_time: 0,
            event_type: EventType::RaceStart,
        };

        assert_eq!(event.event_time, 0);
        assert_eq!(event.event_type, EventType::RaceStart);
    }

    #[test]
    fn test_event_type_variants() {
        let race_start = EventType::RaceStart;
        let car_event = EventType::CarEvent("12".to_string(), CarEventType::Retirement);

        match race_start {
            EventType::RaceStart => assert!(true),
            _ => assert!(false),
        }

        match car_event {
            EventType::CarEvent(car_number, event_type) => {
                assert_eq!(car_number, "12");
                assert_eq!(event_type, CarEventType::Retirement);
            }
            _ => assert!(false),
        }
    }

    #[test]
    fn test_car_event_type_variants() {
        let retirement = CarEventType::Retirement;
        let checkered = CarEventType::Checkered;
        let test_lap = Lap::new(
            "1".to_string(),
            "Test Driver".to_string(),
            5,
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
        );
        let lap_completed = CarEventType::LapCompleted {
            lap_number: 5,
            next_lap: test_lap.clone(),
        };
        let pit_in = CarEventType::PitIn(PitInEvent {
            lap_number: 6,
            duration: 69953, // 1:09.953
        });
        let pit_out = CarEventType::PitOut(PitOutEvent {
            lap_number: 6,
            duration: 69953, // 1:09.953
        });

        assert_eq!(retirement, CarEventType::Retirement);
        assert_eq!(checkered, CarEventType::Checkered);
        assert_eq!(
            lap_completed,
            CarEventType::LapCompleted {
                lap_number: 5,
                next_lap: test_lap
            }
        );
        assert_eq!(
            pit_in,
            CarEventType::PitIn(PitInEvent {
                lap_number: 6,
                duration: 69953
            })
        );
        assert_eq!(
            pit_out,
            CarEventType::PitOut(PitOutEvent {
                lap_number: 6,
                duration: 69953
            })
        );
    }

#[test]
    fn test_timeline_event_json_serialization() {
        let event = TimelineEvent {
            event_time: 95365, // 1:35.365
            event_type: EventType::RaceStart,
        };

        let json = serde_json::to_string(&event).unwrap();

        // event_timeが文字列形式で出力されることを確認
        assert!(json.contains("\"event_time\":\"1:35.365\""));
        assert!(json.contains("\"event_type\":\"RaceStart\""));
    }

}
