/// CSV ファイルステム (`le_mans_24h` 等) を表示名 (`"24 Hours of Le Mans"`)
/// に変換する。Rust 版 `cli::events::display_name` (cli/src/events.rs L17-32)
/// と同じテーブルを保持する。未知の ID はそのまま返す (フェイルセーフ)。
///
/// Rust 版との差異: Rust 版は未知 ID 初出時に `log::warn!` を出力する
/// (events.rs L34-41 の `warn_once`)。flix 版は純関数性を保つため警告を
/// 省略しており、未知 ID は静かに pass-through する。
mod Events {

    pub def displayName(eventId: String): String =
        match eventId {
            case "qatar_1812km"  => "Qatar 1812km"
            case "imola_6h"      => "6 Hours of Imola"
            case "spa_6h"        => "6 Hours of Spa"
            case "le_mans_24h"   => "24 Hours of Le Mans"
            case "cota_6h"       => "Lone Star Le Mans"
            case "fuji_6h"       => "6 Hours of Fuji"
            case "bahrain_8h"    => "8 Hours of Bahrain"
            case "sao_paulo_6h"  => "6 Hours of São Paulo"
            case other           => other
        }

}
