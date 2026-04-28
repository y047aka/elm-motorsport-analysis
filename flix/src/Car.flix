/// スタートグリッド計算用の車両集約型。1 つの `carNumber` ごとに
/// ドライバー一覧 (CSV 出現順) と車両メタを保持する。
/// Rust 版 `motorsport::car::Car` + `MetaData` の組合せに対応する。
mod Car {

    pub type alias Car = {
        carNumber     = String,
        drivers       = List[String],
        class         = String,
        group         = String,
        team          = String,
        manufacturer  = String,
        lap1Elapsed   = Option[Int32],
        startPosition = Int32
    }

}
