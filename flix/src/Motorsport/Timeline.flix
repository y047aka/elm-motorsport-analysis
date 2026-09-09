/// The race as a list of things that happened, in the order they happened.
///
/// The mirror of `Motorsport.Race.TimelineEvent` on the Elm side, which reads
/// these back a line at a time. What is decided here is what the rows do not
/// say -- whether a car's last lap was the flag or a retirement -- and the
/// counting that finds each event is `Round.Timeline`'s.
mod Motorsport.Timeline {

    use Util.Duration.Duration
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt}

    pub enum CarEvent with Eq {
        case Start
        case TookLead
        case PitIn(Int32, Duration)
        case PitOut(Int32, Duration)
        case Retirement
        case Checkered
    }

    pub enum EventType with Eq {
        case RaceStart
        case Of(String, CarEvent)
    }

    pub type alias Event = {
        elapsed   = Duration,
        eventType = EventType
    }

    /// What the events of one round are gathered from: each car's first and
    /// last moment, every stop, and every change of the lead.
    pub type alias Readings = {
        timeLimit = Duration,
        cars      = List[(String, Duration)],
        stops     = List[(String, Int32, Duration, Duration)],
        leads     = List[(String, Duration)]
    }

    /// The race start, one `Start` and one terminal event per car, two events
    /// per stop, and a `TookLead` per change of the lead, in time order.
    ///
    /// Events sharing an instant keep the order the phases are gathered in,
    /// which is what decides a car's status where two of them land together: a
    /// stop ending as the flag falls leaves the car classified rather than in
    /// the pits. `List.sortBy` is not stable, so that order is carried in the
    /// key rather than left to the sort -- a car's `Start` and the race's own
    /// both sit at nought, and so does every other car's.
    pub def fromReadings(readings: Readings): List[Event] =
        List.flatten(
            (raceStart() :: Nil) ::
            starts(readings#cars) ::
            leads(readings#leads) ::
            stops(readings#stops) ::
            terminals(readings#timeLimit, readings#cars) ::
            Nil
        )
            |> List.zipWithIndex
            |> List.sortBy(match (gathered, event) -> (event#elapsed, gathered))
            |> List.map(snd)

    def raceStart(): Event =
        { elapsed = Util.Duration.zero(), eventType = EventType.RaceStart }

    def starts(cars: List[(String, Duration)]): List[Event] =
        cars |> List.map(match (carNumber, _) ->
            { elapsed = Util.Duration.zero(), eventType = EventType.Of(carNumber, CarEvent.Start) })

    def leads(changes: List[(String, Duration)]): List[Event] =
        changes |> List.map(match (carNumber, elapsed) ->
            { elapsed = elapsed, eventType = EventType.Of(carNumber, CarEvent.TookLead) })

    /// A stop is read off the lap it ended on, so the lap carries when the car
    /// came out and how long it was in; when it went in is the difference.
    ///
    /// A stop longer than the race was old when it ended went in before the
    /// start, which is not a moment of the race: the start stands in for it, as
    /// `Motorsport.Instant.fromDuration` makes it on the Elm side. Written out,
    /// a negative would be spelled in a way nothing reads back.
    def stops(rows: List[(String, Int32, Duration, Duration)]): List[Event] =
        rows |> List.flatMap(match (carNumber, lapNumber, elapsed, duration) ->
            let entered = atOrAfterStart(
                Util.Duration.millis(elapsed) - Util.Duration.millis(duration));
            { elapsed = entered, eventType = EventType.Of(carNumber, CarEvent.PitIn(lapNumber, duration)) } ::
            { elapsed = elapsed, eventType = EventType.Of(carNumber, CarEvent.PitOut(lapNumber, duration)) } ::
            Nil)

    def atOrAfterStart(ms: Int32): Duration =
        if (ms < 0) Util.Duration.zero() else Util.Duration.fromMillis(ms)

    /// A car still running when the race was scheduled to end took the flag;
    /// one whose last lap fell short of it retired. The rows say when each car
    /// stopped and not why, and the time limit is `Metadata`'s estimate rather
    /// than anything the feed states.
    def terminals(timeLimit: Duration, cars: List[(String, Duration)]): List[Event] =
        cars |> List.map(match (carNumber, last) ->
            let ended = if (last < timeLimit) CarEvent.Retirement else CarEvent.Checkered;
            { elapsed = last, eventType = EventType.Of(carNumber, ended) })

    pub def toJson(event: Event): Encode.JsonValue =
        JsonObject(
            ("elapsed", JsonString(Util.Duration.format(event#elapsed))) ::
            typeToJson(event#eventType)
        )

    def typeToJson(eventType: EventType): List[(String, Encode.JsonValue)] =
        match eventType {
            case EventType.RaceStart => ("event", JsonString("raceStart")) :: Nil
            case EventType.Of(carNumber, carEvent) =>
                ("event", JsonString(nameOf(carEvent))) ::
                ("carNumber", JsonString(carNumber)) ::
                stopToJson(carEvent)
        }

    def nameOf(carEvent: CarEvent): String =
        match carEvent {
            case CarEvent.Start       => "start"
            case CarEvent.TookLead    => "tookLead"
            case CarEvent.PitIn(_, _) => "pitIn"
            case CarEvent.PitOut(_, _) => "pitOut"
            case CarEvent.Retirement  => "retirement"
            case CarEvent.Checkered   => "checkered"
        }

    def stopToJson(carEvent: CarEvent): List[(String, Encode.JsonValue)] =
        match carEvent {
            case CarEvent.PitIn(lap, duration)  => stopFields(lap, duration)
            case CarEvent.PitOut(lap, duration) => stopFields(lap, duration)
            case _                              => Nil
        }

    def stopFields(lap: Int32, duration: Duration): List[(String, Encode.JsonValue)] =
        ("lap", JsonInt(lap)) ::
        ("duration", JsonString(Util.Duration.format(duration))) ::
        Nil

}
