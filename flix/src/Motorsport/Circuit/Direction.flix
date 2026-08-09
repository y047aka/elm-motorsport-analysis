/// Which way round a circuit the cars go. Mirrors
/// `Motorsport.Circuit.Direction` on the Elm side.
mod Motorsport.Circuit.Direction {

    pub enum Direction with Eq {
        case Clockwise
        case CounterClockwise
    }

    pub def jsonValue(direction: Direction): String =
        match direction {
            case Direction.Clockwise        => "clockwise"
            case Direction.CounterClockwise => "counter_clockwise"
        }

}
