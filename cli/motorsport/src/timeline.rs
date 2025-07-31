use crate::car::CarNumber;
use crate::{Car, Duration, duration};
use serde::{Deserialize, Serialize, Serializer};

/// タイムラインイベント（レース中の時刻ベースのイベント）
#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
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

/// イベントタイプ
#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub enum EventType {
    RaceStart,
    CarEvent(CarNumber, CarEventType),
}

/// 車両イベントタイプ
#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub enum CarEventType {
    Retirement,
    Checkered,
    LapCompleted(u32),
}

/// 車両データから時間制限を計算する関数
/// ElmのcalcTimeLimitロジックをRustに移植
pub fn calc_time_limit(cars: &[Car]) -> Duration {
    cars.iter()
        .filter_map(|car| car.laps.last().map(|lap| lap.elapsed))
        .max()
        .map(|time_limit| (time_limit / (60 * 60 * 1000)) * 60 * 60 * 1000)
        .unwrap_or(0)
}

/// 車両から各種イベント時刻を事前計算する関数
///
/// ElmのcalcEventsロジックをRustに移植
/// - レーススタートイベント（時刻0）
/// - 各車両のラップ完了イベント
/// - 各車両の最終イベント（リタイアまたはチェッカー）
pub fn calc_timeline_events(time_limit: Duration, cars: &[Car]) -> Vec<TimelineEvent> {
    let mut events = Vec::new();

    // レーススタートイベント（1つのみ、全車両に適用）
    events.push(TimelineEvent {
        event_time: 0,
        event_type: EventType::RaceStart,
    });

    // 各車のラップ完了イベント
    for car in cars {
        for lap in &car.laps {
            events.push(TimelineEvent {
                event_time: lap.elapsed,
                event_type: EventType::CarEvent(
                    car.meta_data.car_number.clone(),
                    CarEventType::LapCompleted(lap.lap),
                ),
            });
        }
    }

    // 既存のリタイア・チェッカーイベント
    for car in cars {
        if let Some(final_lap) = car.laps.last() {
            // 時間制限より前に終わった車両はリタイア、以降はチェッカー
            let event_type = if final_lap.elapsed < time_limit {
                EventType::CarEvent(car.meta_data.car_number.clone(), CarEventType::Retirement)
            } else {
                EventType::CarEvent(car.meta_data.car_number.clone(), CarEventType::Checkered)
            };

            events.push(TimelineEvent {
                event_time: final_lap.elapsed,
                event_type,
            });
        }
    }

    // イベント時刻の昇順でソート
    events.sort_by_key(|event| event.event_time);
    events
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_timeline_event_creation() {
        // Red: TimelineEvent構造体がまだ存在しないため、このテストは失敗する
        let event = TimelineEvent {
            event_time: 0,
            event_type: EventType::RaceStart,
        };

        assert_eq!(event.event_time, 0);
        assert_eq!(event.event_type, EventType::RaceStart);
    }

    #[test]
    fn test_event_type_variants() {
        // Red: EventType enumがまだ存在しないため、このテストは失敗する
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
        // Red: CarEventType enumがまだ存在しないため、このテストは失敗する
        let retirement = CarEventType::Retirement;
        let checkered = CarEventType::Checkered;
        let lap_completed = CarEventType::LapCompleted(5);

        assert_eq!(retirement, CarEventType::Retirement);
        assert_eq!(checkered, CarEventType::Checkered);
        assert_eq!(lap_completed, CarEventType::LapCompleted(5));
    }

    #[test]
    fn test_calc_time_limit() {
        let car = create_test_car_with_laps();
        let cars = vec![car];

        let time_limit = calc_time_limit(&cars);

        // 最後のラップのelapsed時間を時間単位に丸めた値になる
        // テストデータの最後のラップは189575ms = 189.575秒 = 0.052時間 -> 0時間 -> 0ms
        assert_eq!(time_limit, 0);
    }

    #[test]
    fn test_calc_time_limit_multiple_hours() {
        use crate::{
            Class, Driver,
            car::{Car, MetaData},
            lap::Lap,
        };

        let drivers = vec![Driver::new("Test Driver".to_string(), false)];
        let metadata = MetaData::new(
            "1".to_string(),
            drivers,
            Class::LMH,
            "H".to_string(),
            "Test Team".to_string(),
            "Test Manufacturer".to_string(),
        );

        // 2時間30分のラップを作成
        let laps = vec![Lap::new(
            "1".to_string(),
            "Test Driver".to_string(),
            1,
            Some(1),
            95365,
            95365,
            23155,
            29928,
            42282,
            23155,
            29928,
            42282,
            9000000, // 2.5時間 = 9,000,000ms
        )];

        let car = Car::new(metadata, 1, laps);
        let cars = vec![car];

        let time_limit = calc_time_limit(&cars);

        // 2.5時間 -> 2時間に丸められる -> 7,200,000ms
        assert_eq!(time_limit, 7200000);
    }

    #[test]
    fn test_calc_timeline_events_empty_cars() {
        // Red: calc_timeline_events関数がまだ存在しないため、このテストは失敗する
        let cars = vec![];
        let time_limit = 7200000; // 2時間

        let events = calc_timeline_events(time_limit, &cars);

        // 車両がない場合でもレーススタートイベントは発生する
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].event_time, 0);
        assert_eq!(events[0].event_type, EventType::RaceStart);
    }

    #[test]
    fn test_calc_timeline_events_single_car_with_laps() {
        // Red: calc_timeline_events関数とテストヘルパーがないため、このテストは失敗する
        let car = create_test_car_with_laps();
        let cars = vec![car];
        let time_limit = 7200000; // 2時間

        let events = calc_timeline_events(time_limit, &cars);

        // レーススタート + ラップ完了イベント + 最終イベント（リタイアorチェッカー）
        assert!(events.len() >= 3);

        // 最初のイベントはレーススタート
        assert_eq!(events[0].event_time, 0);
        assert_eq!(events[0].event_type, EventType::RaceStart);

        // イベント時刻の昇順ソートを確認
        for i in 1..events.len() {
            assert!(events[i - 1].event_time <= events[i].event_time);
        }
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

    // テストヘルパー関数
    fn create_test_car_with_laps() -> Car {
        use crate::{
            Class, Driver,
            car::{Car, MetaData},
            lap::Lap,
        };

        let drivers = vec![Driver::new("Test Driver".to_string(), false)];
        let metadata = MetaData::new(
            "1".to_string(),
            drivers,
            Class::LMH,
            "H".to_string(),
            "Test Team".to_string(),
            "Test Manufacturer".to_string(),
        );

        let laps = vec![
            Lap::new(
                "1".to_string(),
                "Test Driver".to_string(),
                1,
                Some(1),
                95365, // 1:35.365
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
                "1".to_string(),
                "Test Driver".to_string(),
                2,
                Some(1),
                94210, // 1:34.210
                94210,
                23000,
                29000,
                42210,
                23000,
                29000,
                42210,
                189575, // 3:09.575
            ),
        ];

        Car::new(metadata, 1, laps)
    }
}
