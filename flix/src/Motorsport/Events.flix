// The Rust version emits log::warn! (warn_once) for unknown IDs, omitted here to keep this pure.
mod Motorsport.Events {

    use Motorsport.Circuit.Direction.Direction

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

    /// `displayName` passes an unrecognized id through, because a name never
    /// seen before is still the best name there is. A direction has no such
    /// answer -- guessing clockwise would draw the whole field going the wrong
    /// way round, which reads as data rather than as a gap -- so an id not
    /// listed here gets none, and the summary leaves the key out.
    ///
    /// Keyed by a string, nothing makes a new round answer. `TestEvents` names
    /// the calendar and asserts each round has a direction, which is what
    /// stands in for the compiler.
    pub def direction(eventId: String): Option[Direction] =
        match eventId {
            case "qatar_1812km"  => Some(Direction.Clockwise)
            case "imola_6h"      => Some(Direction.CounterClockwise)
            case "spa_6h"        => Some(Direction.Clockwise)
            case "le_mans_24h"   => Some(Direction.Clockwise)
            case "cota_6h"       => Some(Direction.CounterClockwise)
            case "fuji_6h"       => Some(Direction.Clockwise)
            case "bahrain_8h"    => Some(Direction.Clockwise)
            case "sao_paulo_6h"  => Some(Direction.CounterClockwise)
            case _               => None
        }

}
