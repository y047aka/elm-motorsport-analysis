/// The round's timeline, both halves of it: counted out of the laps for the
/// load to write down, and read back out of the rows it wrote. The counting is
/// four readings of the laps -- each car's last moment, each overtake for a
/// class's lead, each time a class's leader went into the pits, each driver
/// change -- and what they add up to is `Motorsport.Timeline`'s.
mod Round.Timeline {

    use Db.Cars
    use Db.Entries
    use Db.Laps
    use Db.Schema
    use Db.TimelineEvents
    use Db.TimelineEvents.EventRow
    use Motorsport.Calendar.Entry
    use Motorsport.Timeline
    use Util.Duration.Duration

    /// Sorted rather than read in the key's order, so that a row corrected in
    /// SQL comes back at its new moment rather than at its old one.
    pub def read(entry: Entry): List[Timeline.Event] \ DbRead =
        let c = TimelineEvents.columns();
        TimelineEvents.rows(entry)
            |> Sql.orderBy(Schema.term(c#elapsedMs) :: Schema.term(c#seq) :: Nil)
            |> Sql.map(_ -> TimelineEvents.selection())
            |> Sql.selectAll
            |> List.map(event)

    /// A row that spells no event is a table written by something other than
    /// `Db.TimelineEvents.fromEvents`, which is the one thing the rows cannot
    /// say for themselves.
    def event(r: EventRow): Timeline.Event \ DbErr =
        match TimelineEvents.toEvent(r) {
            case Some(e) => e
            case None    => DbErr.fail(Db.Error.Incomplete(
                "timeline event ${r#seq} is a \"${r#event}\" carrying nothing that spells one"))
        }

    /// `timeLimit` is `Metadata`'s reading of how far the race was scheduled to
    /// run -- the one thing here the laps do not say -- so the round's
    /// particulars are read first and hand it over.
    pub def fromLaps(entry: Entry, timeLimit: Duration): List[Timeline.Event] \ DbRead =
        Timeline.fromReadings({
            timeLimit = timeLimit,
            cars      = cars(entry),
            overtakes     = overtakes(entry),
            inPits        = leadersInPit(entry),
            driverChanges = driverChanges(entry)
        })

    // ------------------------------------------------------------------ cars

    /// Each car that turned a lap, with the moment it last crossed the line,
    /// in the order the file first showed them.
    ///
    /// A car's laps only ever run forwards, so its latest crossing is the one
    /// its last lap made, and no lap number is read to find it.
    def cars(entry: Entry): List[(String, Duration)] \ DbRead =
        let c = Laps.columns();
        Laps.rows(entry)
            |> Sql.groupBy(Schema.term(c#carNumber) :: Nil)
            |> Sql.orderBy(Sql.raw("MIN(source_row)") :: Nil)
            |> Sql.map(row -> (row#carNumber, Sql.int("MAX(elapsed_ms)")))
            |> Sql.reading(match (carNumber, last) -> (carNumber, Util.Duration.fromMillis(last)))
            |> Sql.selectAll

    // --------------------------------------------------------- driver changes

    /// Every lap whose driver is not the one of the car's lap before it, timed at
    /// that lap before's crossing: the lap in progress from there on is the new
    /// driver's, which is when the app reads the car as theirs.
    ///
    /// Every change in the rounds loaded falls on an out-lap, but nothing here asks
    /// for one: a change the feed writes elsewhere is still a change.
    def driverChanges(entry: Entry): List[Timeline.DriverChange] \ DbRead =
        Sql.rows(Sql.raw("seated"))
            |> Sql.using(Sql.frags(
                Sql.raw("seated AS (SELECT car_number, driver_number,"
                    + " LAG(driver_number) OVER (PARTITION BY car_number ORDER BY lap_number) AS prior,"
                    + " LAG(elapsed_ms) OVER (PARTITION BY car_number ORDER BY lap_number) AS handed_at"
                    + " FROM " + Laps.table() + " WHERE") ::
                Sql.term(Laps.inRound(entry)) ::
                Sql.raw(")") :: Nil
            ))
            |> Sql.filter(_ -> Sql.column("prior IS NOT NULL AND prior <> driver_number"))
            |> Sql.orderBy(Sql.raw("handed_at") :: Nil)
            |> Sql.map(_ -> (Sql.text("car_number"), Sql.int("handed_at")))
            |> Sql.reading(match (carNumber, elapsed) ->
                { carNumber = carNumber, elapsed = Util.Duration.fromMillis(elapsed) })
            |> Sql.selectAll

    // ------------------------------------------------------------ overtakes

    /// Where a class's lead changed hands on the track: the car that took it and
    /// the crossing that took it.
    ///
    /// The lead is a class's order at a lap boundary, read the way
    /// `Round.Laps.placeInField` reads the field's: the first of the class's rows
    /// carrying a lap number. The top class's lead is the field's in every round
    /// loaded, so no lead is counted over the whole field beside it. Whoever led
    /// the opening lap took it from nobody, which is what `LAG` answering null is.
    ///
    /// The two windows are a query each because SQLite settles a `WHERE`
    /// before either of them: the leaders are picked out in `l`, and only then
    /// is each one asked who led the lap before.
    ///
    /// A boundary the car that lost the lead crossed in the pit lane, turning into it
    /// or coming back out of it, is not an overtake and is not here: whoever stayed
    /// out is in front without having overtaken anyone, and the stop that did it is
    /// `leadersInPit`' event.
    def overtakes(entry: Entry): List[Timeline.Overtake] \ DbRead =
        Sql.rows(Sql.raw("(" + handedOver() + ") AS led"))
            |> Sql.using(stopCrossings(entry))
            |> Sql.filter(_ -> Sql.column("held IS NOT NULL AND held <> car_number"))
            |> Sql.filter(_ -> Sql.column("NOT " + crossedInPits("led.held", "led.lap_number")))
            |> Sql.orderBy(Sql.raw("elapsed_ms") :: Nil)
            |> Sql.map(_ -> (Sql.text("car_number"), Sql.int("elapsed_ms")))
            |> Sql.reading(match (carNumber, elapsed) ->
                { carNumber = carNumber, elapsed = Util.Duration.fromMillis(elapsed) })
            |> Sql.selectAll

    // ---------------------------------------------------------------- in pit

    /// Every time the car leading its class went into the pits, whether the lead
    /// changed hands over the stop or not: the crossing at which it turned down the
    /// pit lane, made by a car that led its class on that lap or the lap before it.
    ///
    /// Asking the lead first is what loses these: a leader with air behind it comes
    /// out in front again and no lap boundary changes hands at all, which is seven of
    /// Le Mans's leader stops -- #51's once it had gone clear in the last four hours.
    ///
    /// The stop is anchored on its out-lap, since that is the one crossing the feed
    /// has to write: a stop's two crossings are sometimes both marked as pit crossings
    /// and the in-lap is sometimes missing, so counting crossings counts some stops
    /// twice and some not at all. `pit_time` is written once per stop, and the event
    /// is timed a lap back where the in-lap crossing is.
    def leadersInPit(entry: Entry): List[Timeline.InPit] \ DbRead =
        Sql.rows(Sql.raw("l AS stop"))
            |> Sql.using(Sql.frags(stopCrossings(entry) :: ledEachLap() :: Nil))
            |> Sql.filter(_ -> Sql.column(stoppedWhileLeading()))
            |> Sql.orderBy(Sql.raw("elapsed_ms") :: Nil)
            |> Sql.map(_ -> (
                Sql.text("car_number"),
                Sql.int(cameInAt("stop.car_number", "stop.lap_number"))
            ))
            |> Sql.reading(match (carNumber, elapsed) ->
                { carNumber = carNumber, elapsed = Util.Duration.fromMillis(elapsed) })
            |> Sql.selectAll

    /// The crossings both readings of a stop are made of: every crossing of the
    /// round's, saying whether it is one half of a stop, whether it is the half a stop
    /// is timed at, the car's class, and who of the class crossed its lap first.
    /// Named `l` because both readings correlate on it by name.
    def stopCrossings(entry: Entry): Sql.Frag =
        Sql.frags(
            Sql.raw("l AS (SELECT ${Laps.table()}.car_number, lap_number, elapsed_ms,"
                + " ${Laps.pitLap()} AS pitted, ${Laps.pitOutLap()} AS stopped,"
                + " ${Entries.table()}.class AS car_class, "
                + firstAcross() + " FROM " + classed() + " WHERE") ::
            Sql.term(Laps.inRound(entry)) ::
            Sql.raw(")") :: Nil
        )

    /// The laps, each beside the class of the car that ran it. A lap with no row in
    /// `cars` has no class and is dropped; the load writes the cars first.
    def classed(): String =
        let laps = Laps.table();
        let cars = Cars.table();
        let entries = Entries.table();
        "${laps} JOIN ${cars} ON ${cars}.round_id = ${laps}.round_id"
            + " AND ${cars}.car_number = ${laps}.car_number"
            + " JOIN ${entries} ON ${entries}.entry_id = ${cars}.entry_id"

    /// Who led their class on each lap, for a query asking who was in the lead around
    /// a stop. The `rn = 1` rows of the crossings, which is the same window
    /// `handedOver` reads. A car only ever leads its own class, so a stop is matched
    /// to its car's leads by the car alone.
    def ledEachLap(): Sql.Frag =
        Sql.raw(", led AS (SELECT car_number, lap_number FROM l WHERE rn = 1)")

    /// A stop the car in the lead made: it led the lap before its out-lap, or the lap
    /// before that -- the leader that lost the lead at the crossing it turned down the
    /// lane from, coming back out one lap later.
    def stoppedWhileLeading(): String =
        "stopped AND EXISTS (SELECT 1 FROM led WHERE led.car_number = stop.car_number"
            + " AND led.lap_number IN (stop.lap_number - 2, stop.lap_number - 1))"

    def firstAcross(): String =
        "ROW_NUMBER() OVER (PARTITION BY ${Entries.table()}.class, lap_number"
            + " ORDER BY elapsed_ms, source_row) AS rn"

    def handedOver(): String =
        "SELECT car_number, lap_number, elapsed_ms,"
            + " LAG(car_number) OVER (PARTITION BY car_class ORDER BY lap_number) AS held"
            + " FROM l WHERE rn = 1"

    /// Whether the car named crossed the lap named as one half of a stop.
    ///
    /// That lap alone, and not the one before it: a leader that came back out in
    /// front has its out-lap there, and an overtake on the lap after is still one.
    ///
    /// The car and lap are given as text because the two readings correlate on rows
    /// neither of them declares columns for, and so are `cameInAt`'s.
    def crossedInPits(car: String, lap: String): String =
        "EXISTS (SELECT 1 FROM l WHERE l.car_number = ${car}"
            + " AND l.lap_number = ${lap} AND l.pitted)"

    /// Where the car named came in, for the out-lap named: of that lap and the one
    /// before it, the earlier of the crossings that are one half of a stop, which is
    /// the in-lap when the feed wrote it.
    def cameInAt(car: String, lap: String): String =
        "(SELECT l.elapsed_ms FROM l WHERE l.car_number = ${car}"
            + " AND l.lap_number BETWEEN ${lap} - 1 AND ${lap}"
            + " AND l.pitted ORDER BY l.lap_number ASC LIMIT 1)"

}
