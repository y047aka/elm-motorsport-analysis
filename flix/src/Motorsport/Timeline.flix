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
    /// last moment, and every change of the lead.
    ///
    /// Not the stops: both halves of one are counted off `pit_time`, which the
    /// laps carry, so the app reads them there.
    pub type alias Readings = {
        timeLimit = Duration,
        cars      = List[(String, Duration)],
        leads     = List[(String, Duration)]
    }

    /// The race start, one `Start` and one terminal event per car, and a
    /// `TookLead` per change of the lead, in time order.
    ///
    /// Events sharing an instant keep the order the phases are gathered in.
    /// `List.sortBy` is not stable, so that order is carried in the key rather
    /// than left to the sort -- a car's `Start` and the race's own both sit at
    /// nought, and so does every other car's, and a report the load counted has
    /// to read back in the order it was written.
    pub def fromReadings(readings: Readings): List[Event] =
        List.flatten(
            (raceStart() :: Nil) ::
            starts(readings#cars) ::
            leads(readings#leads) ::
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

    /// A car still running when the race was scheduled to end took the flag;
    /// one whose last lap fell short of it retired. The rows say when each car
    /// stopped and not why, and the time limit is `Metadata`'s estimate rather
    /// than anything the feed states.
    def terminals(timeLimit: Duration, cars: List[(String, Duration)]): List[Event] =
        cars |> List.map(match (carNumber, last) ->
            let ended = if (last < timeLimit) CarEvent.Retirement else CarEvent.Checkered;
            { elapsed = last, eventType = EventType.Of(carNumber, ended) })

    /// What an event is made of, in the words the file spells it in. The line
    /// written out and the row `Db.TimelineEvents` holds are two writings of
    /// this, so which fields an event carries is settled here rather than
    /// beside either of them.
    pub type alias Parts = {
        event     = String,
        carNumber = Option[String]
    }

    /// The names an event goes by, which is what the column holding one is
    /// checked against.
    pub def names(): List[String] =
        "raceStart" ::
        "start" ::
        "tookLead" ::
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
            case CarEvent.Start      => named("start")
            case CarEvent.TookLead   => named("tookLead")
            case CarEvent.Retirement => named("retirement")
            case CarEvent.Checkered  => named("checkered")
        }

    def named(event: String): Parts =
        { event = event, carNumber = None }

    pub def eventTypeOf(p: Parts): Option[EventType] =
        match (p#event, p#carNumber) {
            case ("raceStart", None)     => Some(EventType.RaceStart)
            case (_, Some(carNumber))    =>
                carEventOf(p#event)
                    |> Option.map(carEvent -> EventType.Of(carNumber, carEvent))
            case _                       => None
        }

    def carEventOf(event: String): Option[CarEvent] =
        match event {
            case "start"      => Some(CarEvent.Start)
            case "tookLead"   => Some(CarEvent.TookLead)
            case "retirement" => Some(CarEvent.Retirement)
            case "checkered"  => Some(CarEvent.Checkered)
            case _            => None
        }

    pub def toJson(event: Event): Encode.JsonValue =
        let p = parts(event#eventType);
        JsonObject(
            ("elapsed", JsonString(Util.Duration.format(event#elapsed))) ::
            ("event", JsonString(p#event)) ::
            carNumberField(p)
        )

    def carNumberField(p: Parts): List[(String, Encode.JsonValue)] =
        match p#carNumber {
            case Some(carNumber) => ("carNumber", JsonString(carNumber)) :: Nil
            case None            => Nil
        }

}
