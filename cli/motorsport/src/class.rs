use serde::Serialize;

/// レースクラス/カテゴリーの定義
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub enum Class {
    None,
    HYPERCAR,
    LMP1,
    LMP2,
    LMGTEPro,
    LMGTEAm,
    LMGT3,
    InnovativeCar,
}
