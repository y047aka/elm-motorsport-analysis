// Rust 版は未知 ID に log::warn! を出す (warn_once) が、純関数性を保つため省略。
pub mod Motorsport.Events {

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
