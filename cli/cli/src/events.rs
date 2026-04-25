//! モータースポーツイベントの識別と表示名マッピング。
//!
//! CLI の入力ファイル名（stem）がイベント ID として機能する（例: `le_mans_24h.csv`
//! → `"le_mans_24h"`）。このモジュールは ID → 表示名の変換表を所有する。

use std::collections::HashSet;
use std::sync::{LazyLock, Mutex};

static WARNED_UNKNOWN: LazyLock<Mutex<HashSet<String>>> =
    LazyLock::new(|| Mutex::new(HashSet::new()));

/// 内部イベント ID を表示名に変換する。
///
/// 未知の ID は原値をそのまま返す。初めて遭遇した未知 ID はプロセス内で一度だけ
/// 警告ログを出し、同じ ID が後続ファイルで再度現れても警告は繰り返さない
/// （ディレクトリ一括処理時のログ洪水を避けるため）。
pub fn display_name(event_id: &str) -> &str {
    match event_id {
        "qatar_1812km" => "Qatar 1812km",
        "imola_6h" => "6 Hours of Imola",
        "spa_6h" => "6 Hours of Spa",
        "le_mans_24h" => "24 Hours of Le Mans",
        "cota_6h" => "Lone Star Le Mans",
        "fuji_6h" => "6 Hours of Fuji",
        "bahrain_8h" => "8 Hours of Bahrain",
        "sao_paulo_6h" => "6 Hours of São Paulo",
        other => {
            warn_once(other);
            other
        }
    }
}

fn warn_once(event_id: &str) {
    let mut warned = WARNED_UNKNOWN
        .lock()
        .expect("WARNED_UNKNOWN mutex poisoned");
    if warned.insert(event_id.to_string()) {
        log::warn!("Unknown event ID '{}', using as-is", event_id);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_name_known_events() {
        assert_eq!(display_name("qatar_1812km"), "Qatar 1812km");
        assert_eq!(display_name("imola_6h"), "6 Hours of Imola");
        assert_eq!(display_name("spa_6h"), "6 Hours of Spa");
        assert_eq!(display_name("le_mans_24h"), "24 Hours of Le Mans");
        assert_eq!(display_name("cota_6h"), "Lone Star Le Mans");
        assert_eq!(display_name("fuji_6h"), "6 Hours of Fuji");
        assert_eq!(display_name("bahrain_8h"), "8 Hours of Bahrain");
        assert_eq!(display_name("sao_paulo_6h"), "6 Hours of São Paulo");
    }

    #[test]
    fn display_name_unknown_event_returns_as_is() {
        assert_eq!(display_name("unknown_event"), "unknown_event");
    }
}
