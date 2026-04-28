/// 車両のドメインメタデータ。Rust 版 `motorsport::car::MetaData`
/// (cli/motorsport/src/car.rs L26-35) に対応する純粋なドメイン型。
/// スタートグリッド計算用の中間状態 (lap1 elapsed, position) は
/// `Metadata.flix` 側の専用型に分離されており、ここには含まれない。
mod Domain.Car {

    pub type alias Car = {
        carNumber    = String,
        drivers      = List[String],
        class        = String,
        group        = String,
        team         = String,
        manufacturer = String
    }

}
