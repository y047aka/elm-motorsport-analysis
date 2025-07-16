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

#[cfg(test)]
mod tests {
    use super::Class;

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
}
