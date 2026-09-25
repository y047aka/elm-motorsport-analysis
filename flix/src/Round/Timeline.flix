/// The round's timeline, both halves of it: counted out of the laps for the
/// load to write down, and read back out of the rows it wrote. The counting is
/// three readings of the laps -- each car's last moment, each pass for the lead,
/// each stop the leader came in on -- and what they add up to is
/// `Motorsport.Timeline`'s.
mod Round.Timeline {

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
            passes    = passes(entry),
            stops     = leaderStops(entry)
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

    // -------------------------------------------------------------- passes

    /// Where the lead changed hands on the track: the car that took it and the
    /// crossing that took it.
    ///
    /// The lead is the field's order at a lap boundary, which is what
    /// `Round.Laps.placeInField` counts, so it is read the same way: the first
    /// of the round's rows carrying a lap number. Whoever led the opening lap
    /// took it from nobody, which is what `LAG` answering null is.
    ///
    /// The two windows are a query each because SQLite settles a `WHERE`
    /// before either of them: the leaders are picked out in `l`, and only then
    /// is each one asked who led the lap before.
    ///
    /// A boundary the car that lost the lead crossed in the pit lane, turning into it
    /// or coming back out of it, is not a pass and is not here: whoever stayed out is
    /// in front without having passed anyone, and the stop that did it is
    /// `leaderStops`' event.
    def passes(entry: Entry): List[Timeline.Pass] \ DbRead =
        Sql.rows(Sql.raw("(" + handedOver() + ") AS led"))
            |> Sql.using(stopCrossings(entry))
            |> Sql.filter(_ -> Sql.column("held IS NOT NULL AND held <> car_number"))
            |> Sql.filter(_ -> Sql.column("NOT " + crossedInPits("led.held", "led.lap_number")))
            |> Sql.orderBy(Sql.raw("lap_number") :: Nil)
            |> Sql.map(_ -> (Sql.text("car_number"), Sql.int("elapsed_ms")))
            |> Sql.reading(match (carNumber, elapsed) ->
                { carNumber = carNumber, elapsed = Util.Duration.fromMillis(elapsed) })
            |> Sql.selectAll

    // ----------------------------------------------------------------- stops

    /// Every stop the car in the lead came in on, whether the lead changed hands over
    /// it or not: the crossing at which it turned down the pit lane, made by a car
    /// that led that lap or the lap before it.
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
    def leaderStops(entry: Entry): List[Timeline.Stop] \ DbRead =
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
    /// is timed at, and who crossed its lap first. Named `l` because both readings
    /// correlate on it by name.
    def stopCrossings(entry: Entry): Sql.Frag =
        Sql.frags(
            Sql.raw("l AS (SELECT car_number, lap_number, elapsed_ms,"
                + " ${Laps.pitLap()} AS pitted, ${Laps.pitOutLap()} AS stopped, "
                + firstAcross() + " FROM " + Laps.table() + " WHERE") ::
            Sql.term(Laps.inRound(entry)) ::
            Sql.raw(")") :: Nil
        )

    /// Who led each lap, for a query asking who was in the lead around a stop. The
    /// `rn = 1` rows of the crossings, which is the same window `handedOver` reads.
    def ledEachLap(): Sql.Frag =
        Sql.raw(", led AS (SELECT car_number, lap_number FROM l WHERE rn = 1)")

    /// A stop the car in the lead made: it led the lap before its out-lap, or the lap
    /// before that -- the leader that lost the lead at the crossing it turned down the
    /// lane from, coming back out one lap later.
    def stoppedWhileLeading(): String =
        "stopped AND EXISTS (SELECT 1 FROM led WHERE led.car_number = stop.car_number"
            + " AND led.lap_number IN (stop.lap_number - 2, stop.lap_number - 1))"

    def firstAcross(): String =
        "ROW_NUMBER() OVER (PARTITION BY lap_number ORDER BY elapsed_ms, source_row) AS rn"

    def handedOver(): String =
        "SELECT car_number, lap_number, elapsed_ms,"
            + " LAG(car_number) OVER (ORDER BY lap_number) AS held"
            + " FROM l WHERE rn = 1"

    /// Whether the car named crossed the lap named as one half of a stop.
    ///
    /// That lap alone, and not the one before it: a leader that came back out in
    /// front has its out-lap there, and a pass on the lap after is still a pass.
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
