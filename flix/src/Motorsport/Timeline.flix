/// The race as a list of things that happened, in the order they happened.
///
/// The mirror of `Motorsport.Race.TimelineEvent` on the Elm side, which reads
/// these back a line at a time. What is decided here is what the rows do not
/// say -- whether a car's last lap was the flag or a retirement -- and the
/// counting that finds each event is `Round.Timeline`'s.
mod Motorsport.Timeline {

    use Motorsport.Flag.Flag
    use Util.Duration.Duration
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt}

    /// What one car did. The lead is the car's class's. `OvertakeForLead` is about
    /// the car that came in front of its class; `LeaderInPit` is about the car that
    /// led it, and says nothing about who took the lead in its place. `DriverChange`
    /// says the car's driver changed and not to whom: that is the car's own laps' to
    /// say.
    pub enum CarEvent with Eq {
        case OvertakeForLead
        case LeaderInPit
        case FastestLap
        case DriverChange
        case Retired
        case Finished
    }

    pub enum EventType with Eq {
        case RaceStart
        case Flag(Flag)
        case Of(String, CarEvent)
    }

    pub type alias Event = {
        elapsed   = Duration,
        eventType = EventType
    }

    /// A car that took the lead by overtaking on track, and the crossing that did it.
    pub type alias Overtake = {
        carNumber = String,
        elapsed   = Duration
    }

    /// The leader's crossing into the pit lane, and whose it was.
    pub type alias InPit = {
        carNumber = String,
        elapsed   = Duration
    }

    /// A car handed to another driver, and the crossing that did it: the last one
    /// the driver before made.
    pub type alias DriverChange = {
        carNumber = String,
        elapsed   = Duration
    }

    /// A lap faster than any its class had run before it, and the crossing that
    /// completed it.
    pub type alias FastestLap = {
        carNumber = String,
        elapsed   = Duration
    }

    /// A flag the line read for the first time since a different one.
    pub type alias FlagShown = {
        flag    = Flag,
        elapsed = Duration
    }

    /// What the events of one round are gathered from, `cars` being each car's last
    /// crossing. A change of the lead the leader's stop settled is no overtake: the
    /// stop is the event, and the car that stayed out in front is in none.
    pub type alias Readings = {
        timeLimit     = Duration,
        cars          = List[(String, Duration)],
        flags         = List[FlagShown],
        overtakes     = List[Overtake],
        inPits        = List[InPit],
        fastestLaps   = List[FastestLap],
        driverChanges = List[DriverChange]
    }

    /// Every event the readings make, in time order.
    ///
    /// Events sharing an instant keep the order the phases are gathered in.
    /// `List.sortBy` is not stable, so that order is carried in the key rather
    /// than left to the sort -- two events one millisecond holds are a report
    /// the load counted, and it has to read back in the order it was written.
    pub def fromReadings(readings: Readings): List[Event] =
        List.flatten(
            (raceStart() :: Nil) ::
            flagsShown(readings#flags) ::
            overtakesForLead(readings#overtakes) ::
            leadersInPit(readings#inPits) ::
            fastestLaps(readings#fastestLaps) ::
            driverChanges(readings#driverChanges) ::
            terminals(readings#timeLimit, readings#cars) ::
            Nil
        )
            |> List.zipWithIndex
            |> List.sortBy(match (gathered, event) -> (event#elapsed, gathered))
            |> List.map(snd)

    def raceStart(): Event =
        { elapsed = Util.Duration.zero(), eventType = EventType.RaceStart }

    def overtakesForLead(overtakes: List[Overtake]): List[Event] =
        overtakes |> List.map(overtake ->
            {
                elapsed = overtake#elapsed,
                eventType = EventType.Of(overtake#carNumber, CarEvent.OvertakeForLead)
            })

    def leadersInPit(inPits: List[InPit]): List[Event] =
        inPits |> List.map(inPit ->
            {
                elapsed = inPit#elapsed,
                eventType = EventType.Of(inPit#carNumber, CarEvent.LeaderInPit)
            })

    def flagsShown(flags: List[FlagShown]): List[Event] =
        flags |> List.map(shown -> { elapsed = shown#elapsed, eventType = EventType.Flag(shown#flag) })

    def fastestLaps(laps: List[FastestLap]): List[Event] =
        laps |> List.map(lap ->
            {
                elapsed = lap#elapsed,
                eventType = EventType.Of(lap#carNumber, CarEvent.FastestLap)
            })

    def driverChanges(changes: List[DriverChange]): List[Event] =
        changes |> List.map(change ->
            {
                elapsed = change#elapsed,
                eventType = EventType.Of(change#carNumber, CarEvent.DriverChange)
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
        ("raceStart" :: List.map(Motorsport.Flag.toString, Motorsport.Flag.all())) ++ (
            "overtakeForLead" ::
            "leaderInPit" ::
            "fastestLap" ::
            "driverChange" ::
            "retired" ::
            "finished" ::
            Nil
        )

    pub def parts(eventType: EventType): Parts =
        match eventType {
            case EventType.RaceStart               => named("raceStart")
            case EventType.Flag(flag)              => named(Motorsport.Flag.toString(flag))
            case EventType.Of(carNumber, carEvent) =>
                { carNumber = Some(carNumber) | carParts(carEvent) }
        }

    def carParts(carEvent: CarEvent): Parts =
        match carEvent {
            case CarEvent.OvertakeForLead => named("overtakeForLead")
            case CarEvent.LeaderInPit     => named("leaderInPit")
            case CarEvent.FastestLap      => named("fastestLap")
            case CarEvent.DriverChange    => named("driverChange")
            case CarEvent.Retired         => named("retired")
            case CarEvent.Finished        => named("finished")
        }

    def named(event: String): Parts =
        { event = event, carNumber = None }

    pub def eventTypeOf(p: Parts): Option[EventType] =
        match (p#event, p#carNumber) {
            case ("raceStart", None)     => Some(EventType.RaceStart)
            case (_, None)               => Motorsport.Flag.fromString(p#event) |> Option.map(EventType.Flag)
            case (_, Some(carNumber))    =>
                carEventOf(p#event)
                    |> Option.map(carEvent -> EventType.Of(carNumber, carEvent))
        }

    def carEventOf(event: String): Option[CarEvent] =
        match event {
            case "overtakeForLead" => Some(CarEvent.OvertakeForLead)
            case "leaderInPit"     => Some(CarEvent.LeaderInPit)
            case "fastestLap"      => Some(CarEvent.FastestLap)
            case "driverChange"    => Some(CarEvent.DriverChange)
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
