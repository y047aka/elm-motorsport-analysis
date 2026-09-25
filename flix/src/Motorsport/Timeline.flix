/// The race as a list of things that happened, in the order they happened.
///
/// The mirror of `Motorsport.Race.TimelineEvent` on the Elm side, which reads
/// these back a line at a time. What is decided here is what the rows do not
/// say -- whether a car's last lap was the flag or a retirement, which changes of
/// the lead were overtakes, and which cars went into the pits leading -- and the
/// counting that finds each event is `Round.Timeline`'s.
mod Motorsport.Timeline {

    use Util.Duration.Duration
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt}

    /// What one car did. The lead is the car's class's, and the top class's is the
    /// field's. `OvertakeForLead` is about the car that came in front of its class;
    /// `LeaderInPit` is about the car that led it and turned into the pit lane, and
    /// says nothing about who took the lead in its place.
    pub enum CarEvent with Eq {
        case OvertakeForLead
        case LeaderInPit
        case Retired
        case Finished
    }

    pub enum EventType with Eq {
        case RaceStart
        case Of(String, CarEvent)
    }

    pub type alias Event = {
        elapsed   = Duration,
        eventType = EventType
    }

    /// A car that took the lead by overtaking on track, and the crossing that did it.
    /// Not every change of the lead is one: `InPit` is the reading of the laps that
    /// says who was in the pits.
    pub type alias Overtake = {
        carNumber = String,
        elapsed   = Duration
    }

    /// The leader's crossing into the pit lane, and whose it was. Whether the lead
    /// changed hands over the stop is neither asked nor said.
    pub type alias InPit = {
        carNumber = String,
        elapsed   = Duration
    }

    /// What the events of one round are gathered from: each car's last moment, every
    /// overtake for the lead, and every time the leader went into the pits.
    ///
    /// A change of the lead the leader's stop settled is in neither: the stop is, and
    /// the car that stayed out in front is in no event at all.
    pub type alias Readings = {
        timeLimit = Duration,
        cars      = List[(String, Duration)],
        overtakes = List[Overtake],
        inPits    = List[InPit]
    }

    /// The race start, one terminal event per car, one per overtake for the lead, and
    /// one per time the leader went into the pits, in time order.
    ///
    /// Not who took the green flag: every car that turned a lap took it, all at
    /// nought, and who was ahead of whom is `Motorsport.Metadata`'s starting grid.
    ///
    /// Events sharing an instant keep the order the phases are gathered in.
    /// `List.sortBy` is not stable, so that order is carried in the key rather
    /// than left to the sort -- two events one millisecond holds are a report
    /// the load counted, and it has to read back in the order it was written.
    pub def fromReadings(readings: Readings): List[Event] =
        List.flatten(
            (raceStart() :: Nil) ::
            overtakesForLead(readings#overtakes) ::
            leadersInPit(readings#inPits) ::
            terminals(readings#timeLimit, readings#cars) ::
            Nil
        )
            |> List.zipWithIndex
            |> List.sortBy(match (gathered, event) -> (event#elapsed, gathered))
            |> List.map(snd)

    def raceStart(): Event =
        { elapsed = Util.Duration.zero(), eventType = EventType.RaceStart }

    /// One event per overtake for the lead, about the car that took it.
    def overtakesForLead(overtakes: List[Overtake]): List[Event] =
        overtakes |> List.map(overtake ->
            {
                elapsed = overtake#elapsed,
                eventType = EventType.Of(overtake#carNumber, CarEvent.OvertakeForLead)
            })

    /// One event per time the leader went into the pits, about the leader and not
    /// about the field behind it, which may not have moved at all.
    def leadersInPit(inPits: List[InPit]): List[Event] =
        inPits |> List.map(inPit ->
            {
                elapsed = inPit#elapsed,
                eventType = EventType.Of(inPit#carNumber, CarEvent.LeaderInPit)
            })

    /// A car still running when the race was scheduled to end took the flag;
    /// one whose last lap fell short of it retired. The rows say when each car
    /// stopped and not why, and the time limit is `Metadata`'s estimate rather
    /// than anything the feed states.
    def terminals(timeLimit: Duration, cars: List[(String, Duration)]): List[Event] =
        cars |> List.map(match (carNumber, last) ->
            let ended = if (last < timeLimit) CarEvent.Retired else CarEvent.Finished;
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
        "overtakeForLead" ::
        "leaderInPit" ::
        "retired" ::
        "finished" ::
        Nil

    pub def parts(eventType: EventType): Parts =
        match eventType {
            case EventType.RaceStart               => named("raceStart")
            case EventType.Of(carNumber, carEvent) =>
                { carNumber = Some(carNumber) | carParts(carEvent) }
        }

    def carParts(carEvent: CarEvent): Parts =
        match carEvent {
            case CarEvent.OvertakeForLead => named("overtakeForLead")
            case CarEvent.LeaderInPit     => named("leaderInPit")
            case CarEvent.Retired         => named("retired")
            case CarEvent.Finished        => named("finished")
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
            case "overtakeForLead" => Some(CarEvent.OvertakeForLead)
            case "leaderInPit"     => Some(CarEvent.LeaderInPit)
            case "retired"         => Some(CarEvent.Retired)
            case "finished"        => Some(CarEvent.Finished)
            case _                 => None
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
