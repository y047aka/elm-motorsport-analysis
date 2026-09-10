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

    /// What an event is made of, in the words the file spells it in: which
    /// event it was, whose it was, and the two things only a stop carries.
    ///
    /// The line written out and the row `Db.TimelineEvents` holds are two
    /// writings of this, so which fields an event carries is settled here
    /// rather than beside either of them.
    pub type alias Parts = {
        event     = String,
        carNumber = Option[String],
        lapNumber = Option[Int32],
        duration  = Option[Duration]
    }

    /// The names an event goes by, which is what the column holding one is
    /// checked against.
    pub def names(): List[String] =
        "raceStart" ::
        "start" ::
        "tookLead" ::
        "pitIn" ::
        "pitOut" ::
        "retirement" ::
        "checkered" ::
        Nil

    pub def parts(eventType: EventType): Parts =
        match eventType {
            case EventType.RaceStart               => named("raceStart")
            case EventType.Of(carNumber, carEvent) =>
                { carNumber = Some(carNumber) | carParts(carEvent) }
        }

    def carParts(carEvent: CarEvent): Parts =
        match carEvent {
            case CarEvent.Start                 => named("start")
            case CarEvent.TookLead              => named("tookLead")
            case CarEvent.PitIn(lap, duration)  => stopParts("pitIn", lap, duration)
            case CarEvent.PitOut(lap, duration) => stopParts("pitOut", lap, duration)
            case CarEvent.Retirement            => named("retirement")
            case CarEvent.Checkered             => named("checkered")
        }

    def named(event: String): Parts =
        { event = event, carNumber = None, lapNumber = None, duration = None }

    def stopParts(event: String, lap: Int32, duration: Duration): Parts =
        { event = event, carNumber = None, lapNumber = Some(lap), duration = Some(duration) }

    /// The event those parts spell, or nothing where they spell none: a name no
    /// event answers to, a car's event with no car, or a stop with neither the
    /// lap it ended on nor its length.
    pub def eventTypeOf(p: Parts): Option[EventType] =
        match (p#event, p#carNumber) {
            case ("raceStart", None)     => Some(EventType.RaceStart)
            case (_, Some(carNumber))    =>
                carEventOf(p#event, p#lapNumber, p#duration)
                    |> Option.map(carEvent -> EventType.Of(carNumber, carEvent))
            case _                       => None
        }

    def carEventOf(event: String, lap: Option[Int32], duration: Option[Duration]): Option[CarEvent] =
        match (event, lap, duration) {
            case ("start", _, _)                     => Some(CarEvent.Start)
            case ("tookLead", _, _)                  => Some(CarEvent.TookLead)
            case ("pitIn", Some(n), Some(length))    => Some(CarEvent.PitIn(n, length))
            case ("pitOut", Some(n), Some(length))   => Some(CarEvent.PitOut(n, length))
            case ("retirement", _, _)                => Some(CarEvent.Retirement)
            case ("checkered", _, _)                 => Some(CarEvent.Checkered)
            case _                                   => None
        }

    pub def toJson(event: Event): Encode.JsonValue =
        let p = parts(event#eventType);
        JsonObject(
            ("elapsed", JsonString(Util.Duration.format(event#elapsed))) ::
            ("event", JsonString(p#event)) ::
            List.append(carNumberField(p), stopFields(p))
        )

    def carNumberField(p: Parts): List[(String, Encode.JsonValue)] =
        match p#carNumber {
            case Some(carNumber) => ("carNumber", JsonString(carNumber)) :: Nil
            case None            => Nil
        }

    def stopFields(p: Parts): List[(String, Encode.JsonValue)] =
        match (p#lapNumber, p#duration) {
            case (Some(lap), Some(duration)) =>
                ("lap", JsonInt(lap)) ::
                ("duration", JsonString(Util.Duration.format(duration))) ::
                Nil
            case _ => Nil
        }

}
