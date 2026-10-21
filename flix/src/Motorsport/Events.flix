pub mod Motorsport.Events {

    use Motorsport.Circuit.Circuit

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

    /// Which ground the round was run on, which the laps say nothing about:
    /// a file of lap times is not a map.
    ///
    /// This is the round's circuit whether or not anything draws it, so the key
    /// is written for every round and the app decides what to draw it with. The
    /// name is the stem the round ids share: see `Motorsport.Circuit`.
    ///
    /// Held here rather than read off the round id by cutting the suffix off,
    /// because the suffixes are not a grammar -- `_6h`, `_8h`, `_24h`, `_1812km`
    /// -- and one that arrives would be cut into a circuit name silently.
    pub def circuit(eventId: String): Option[Circuit] =
        match eventId {
            case "qatar_1812km"  => Some(Circuit.Qatar)
            case "imola_6h"      => Some(Circuit.Imola)
            case "spa_6h"        => Some(Circuit.Spa)
            case "le_mans_24h"   => Some(Circuit.LeMans)
            case "cota_6h"       => Some(Circuit.Cota)
            case "fuji_6h"       => Some(Circuit.Fuji)
            case "bahrain_8h"    => Some(Circuit.Bahrain)
            case "sao_paulo_6h"  => Some(Circuit.SaoPaulo)
            case _               => None
        }

}
