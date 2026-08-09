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

    /// Which way round the circuit a round is run on goes.
    ///
    /// `displayName` can pass an unrecognized id through, because a name it has
    /// never seen is still the best name there is. A direction has no such
    /// answer: guessing clockwise for a circuit that is not would draw the
    /// whole field going the wrong way round, which reads as data rather than
    /// as a gap. So this says nothing instead, and the summary leaves the key
    /// out.
    ///
    /// The Elm side used to hold this keyed by a `Wec` constructor, where the
    /// compiler would not let a round go unanswered. Keyed by the id off a
    /// filename there is no such check, and a round added to the calendar
    /// without a line here is what the `None` is for.
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
