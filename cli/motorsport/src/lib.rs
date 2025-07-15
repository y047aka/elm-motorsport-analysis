pub type Duration = u32;

pub mod duration {
    use super::Duration;

    /// Duration文字列をミリ秒に変換
    /// 例: "1:35.365" -> 95365, "23.155" -> 23155
    pub fn from_string(s: &str) -> Option<Duration> {
        let parts: Vec<&str> = s.split(':').collect();

        match parts.as_slice() {
            // "hh:mm:ss.ms" 形式
            [h, m, s] => {
                let hours = h.parse::<u32>().ok()?;
                let minutes = m.parse::<u32>().ok()?;
                let seconds = s.parse::<f64>().ok()?;
                Some(hours * 3600000 + minutes * 60000 + (seconds * 1000.0) as u32)
            }
            // "mm:ss.ms" 形式
            [m, s] => {
                let minutes = m.parse::<u32>().ok()?;
                let seconds = s.parse::<f64>().ok()?;
                Some(minutes * 60000 + (seconds * 1000.0) as u32)
            }
            // "ss.ms" 形式
            [s] => {
                let seconds = s.parse::<f64>().ok()?;
                Some((seconds * 1000.0) as u32)
            }
            _ => None,
        }
    }

    /// ミリ秒をDuration文字列に変換
    pub fn to_string(ms: Duration) -> String {
        if ms >= 3600000 {
            // 1時間以上
            let hours = ms / 3600000;
            let minutes = (ms % 3600000) / 60000;
            let seconds = ((ms % 60000) as f64) / 1000.0;
            format!("{}:{:02}:{:06.3}", hours, minutes, seconds)
        } else if ms >= 60000 {
            // 1分以上
            let minutes = ms / 60000;
            let seconds = ((ms % 60000) as f64) / 1000.0;
            format!("{}:{:06.3}", minutes, seconds)
        } else {
            // 1分未満
            let seconds = (ms as f64) / 1000.0;
            format!("{:.3}", seconds)
        }
    }
}


/// Motorsportライブラリ - Elmから移植
pub mod motorsport {
    use serde::{Deserialize, Serialize};

    /// レースクラス/カテゴリーの定義
    #[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
    pub enum Class {
        None,
        LMH,
        LMP1,
        LMP2,
        LMGTEPro,
        LMGTEAm,
        LMGT3,
        InnovativeCar,
    }

    impl Class {
        /// クラスを文字列に変換（ElmのtoStringと互換）
        pub fn to_string(&self) -> &'static str {
            match self {
                Class::None => "None",
                Class::LMH => "HYPERCAR",
                Class::LMP1 => "LMP1",
                Class::LMP2 => "LMP2",
                Class::LMGTEPro => "LMGTE Pro",
                Class::LMGTEAm => "LMGTE Am",
                Class::LMGT3 => "LMGT3",
                Class::InnovativeCar => "INNOVATIVE CAR",
            }
        }

        /// 文字列からクラスを生成（ElmのfromStringと互換）
        pub fn from_string(s: &str) -> Option<Self> {
            match s {
                "None" => Some(Class::None),
                "HYPERCAR" => Some(Class::LMH),
                "LMP1" => Some(Class::LMP1),
                "LMP2" => Some(Class::LMP2),
                "LMGTE Pro" => Some(Class::LMGTEPro),
                "LMGTE Am" => Some(Class::LMGTEAm),
                "LMGT3" => Some(Class::LMGT3),
                "INNOVATIVE CAR" => Some(Class::InnovativeCar),
                _ => None,
            }
        }

        /// クラスの16進数カラーコードを取得（ElmのtoHexColorを簡略化）
        pub fn to_hex_color(&self, season: u32) -> &'static str {
            match self {
                Class::None => "#000",
                Class::LMH => "#f00",
                Class::LMP1 => "#f00",
                Class::LMP2 => "#00f",
                Class::LMGTEPro => "#060",
                Class::LMGTEAm => "#f60",
                Class::LMGT3 => {
                    if season > 2024 {
                        "#060"
                    } else {
                        "#f60"
                    }
                }
                Class::InnovativeCar => "#00f",
            }
        }
    }

    /// ドライバー情報
    #[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
    pub struct Driver {
        pub name: String,
        pub is_current_driver: bool,
    }

    impl Driver {
        /// 新しいドライバーを作成
        pub fn new(name: String, is_current: bool) -> Self {
            Driver {
                name,
                is_current_driver: is_current,
            }
        }
    }

    /// ドライバーリストから現在のドライバーを検索
    pub fn find_current_driver(drivers: &[Driver]) -> Option<&Driver> {
        drivers.iter().find(|d| d.is_current_driver)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use motorsport::*;

    #[test]
    fn test_duration_from_string() {
        assert_eq!(duration::from_string("1:35.365"), Some(95365));
        assert_eq!(duration::from_string("23.155"), Some(23155));
        assert_eq!(duration::from_string("0:29.928"), Some(29928));
        assert_eq!(duration::from_string("7:06:54.321"), Some(25614321));
    }

    #[test]
    fn test_duration_to_string() {
        assert_eq!(duration::to_string(95365), "1:35.365");
        assert_eq!(duration::to_string(23155), "23.155");
        assert_eq!(duration::to_string(29928), "29.928");
        assert_eq!(duration::to_string(25614321), "7:06:54.321");
    }

    #[test]
    fn test_class_to_string() {
        // Elmの実装と互換性を確認
        assert_eq!(Class::None.to_string(), "None");
        assert_eq!(Class::LMH.to_string(), "HYPERCAR");
        assert_eq!(Class::LMP1.to_string(), "LMP1");
        assert_eq!(Class::LMP2.to_string(), "LMP2");
        assert_eq!(Class::LMGTEPro.to_string(), "LMGTE Pro");
        assert_eq!(Class::LMGTEAm.to_string(), "LMGTE Am");
        assert_eq!(Class::LMGT3.to_string(), "LMGT3");
        assert_eq!(Class::InnovativeCar.to_string(), "INNOVATIVE CAR");
    }

    #[test]
    fn test_class_from_string() {
        // 正常なケース
        assert_eq!(Class::from_string("None"), Some(Class::None));
        assert_eq!(Class::from_string("HYPERCAR"), Some(Class::LMH));
        assert_eq!(Class::from_string("LMP1"), Some(Class::LMP1));
        assert_eq!(Class::from_string("LMP2"), Some(Class::LMP2));
        assert_eq!(Class::from_string("LMGTE Pro"), Some(Class::LMGTEPro));
        assert_eq!(Class::from_string("LMGTE Am"), Some(Class::LMGTEAm));
        assert_eq!(Class::from_string("LMGT3"), Some(Class::LMGT3));
        assert_eq!(Class::from_string("INNOVATIVE CAR"), Some(Class::InnovativeCar));

        // 不正なケース
        assert_eq!(Class::from_string("UNKNOWN"), None);
        assert_eq!(Class::from_string(""), None);
        assert_eq!(Class::from_string("lmp1"), None); // 大文字小文字の区別
    }

    #[test]
    fn test_class_round_trip() {
        // 文字列変換の往復テスト
        let classes = vec![
            Class::None,
            Class::LMH,
            Class::LMP1,
            Class::LMP2,
            Class::LMGTEPro,
            Class::LMGTEAm,
            Class::LMGT3,
            Class::InnovativeCar,
        ];

        for class in classes {
            let string_repr = class.to_string();
            let parsed_class = Class::from_string(string_repr);
            assert_eq!(Some(class), parsed_class);
        }
    }

    #[test]
    fn test_class_hex_colors() {
        // 2024年シーズンのカラー
        assert_eq!(Class::None.to_hex_color(2024), "#000");
        assert_eq!(Class::LMH.to_hex_color(2024), "#f00");
        assert_eq!(Class::LMP1.to_hex_color(2024), "#f00");
        assert_eq!(Class::LMP2.to_hex_color(2024), "#00f");
        assert_eq!(Class::LMGTEPro.to_hex_color(2024), "#060");
        assert_eq!(Class::LMGTEAm.to_hex_color(2024), "#f60");
        assert_eq!(Class::LMGT3.to_hex_color(2024), "#f60");
        assert_eq!(Class::InnovativeCar.to_hex_color(2024), "#00f");

        // 2025年以降（LMGT3のカラーが変わる）
        assert_eq!(Class::LMGT3.to_hex_color(2025), "#060");
    }

    #[test]
    fn test_find_current_driver() {
        let drivers = vec![
            Driver::new("Will STEVENS".to_string(), false),
            Driver::new("Kamui KOBAYASHI".to_string(), true),
            Driver::new("Mike CONWAY".to_string(), false),
        ];

        let current = find_current_driver(&drivers);
        assert!(current.is_some());
        assert_eq!(current.unwrap().name, "Kamui KOBAYASHI");
    }

    #[test]
    fn test_find_current_driver_none() {
        let drivers = vec![
            Driver::new("Will STEVENS".to_string(), false),
            Driver::new("Mike CONWAY".to_string(), false),
        ];

        let current = find_current_driver(&drivers);
        assert!(current.is_none());
    }

    #[test]
    fn test_find_current_driver_empty() {
        let drivers: Vec<Driver> = vec![];
        let current = find_current_driver(&drivers);
        assert!(current.is_none());
    }
}
