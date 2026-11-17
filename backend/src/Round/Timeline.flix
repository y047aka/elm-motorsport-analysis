/// The round's timeline, both halves of it: counted out of the laps for the
/// load to write down, and read back out of the rows it wrote. The counting is
/// a reading of the laps per kind of event, and what they add up to is
/// `Motorsport.Timeline`'s.
pub mod Round.Timeline {

    use Db.Cars
    use Db.Entries
    use Db.Laps
    use Db.Schema
    use Db.TimelineEvents
    use Db.TimelineEvents.EventRow
    use Db.Value
    use Motorsport.Calendar.Entry
    use Motorsport.Index
    use Motorsport.Index.Record
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Motorsport.Sector
    use Motorsport.Sector.Sector
    use Motorsport.Timeline
    use Motorsport.Timeline.CarEvent
    use Motorsport.Timeline.EventType
    use Sql.Sel
    use Util.Duration.Duration

    /// The round's timeline as the rows hold it: every event with the lap it fell on,
    /// and nothing beside it.
    ///
    /// Sorted rather than read in the key's order, so that a row corrected in SQL comes
    /// back at its new moment rather than at its old one.
    pub def read(entry: Entry): List[Timeline.Event] \ DbRead =
        let c = TimelineEvents.columns();
        TimelineEvents.rows(entry)
            |> Sql.orderBy(Schema.term(c#elapsedMs) :: Schema.term(c#seq) :: Nil)
            |> Sql.map(_ -> TimelineEvents.selection())
            |> Sql.selectAll
            |> List.map(event)

    /// The round's timeline, each event that fell on a timed lap beside that lap's
    /// driver and the times it ran.
    ///
    /// `index` is the round's own, so the records a lap reads against are the ones
    /// `Round.Index` counted.
    pub def detailed(
        entry: Entry,
        seats: Round.Drivers.Seats,
        index: Index.Index
    ): List[Detailed] \ DbRead =
        let happening = read(entry);
        let cells = lapCells(entry, List.filterMap(lapOf, happening));
        happening |> List.map(beside(seats, index, cells))

    /// A row that spells no event is a table written by something other than
    /// `Db.TimelineEvents.fromEvents`, which is the one thing the rows cannot
    /// say for themselves.
    def event(r: EventRow): Timeline.Event \ DbErr =
        match TimelineEvents.toEvent(r) {
            case Some(e) => e
            case None    => DbErr.raise(Db.Error.Incomplete(
                "timeline event ${r#seq} is a \"${r#event}\" carrying nothing that spells one"))
        }

    /// `timeLimit` is `Metadata`'s reading of how far the race was scheduled to
    /// run -- the one thing here the laps do not say -- so the round's
    /// particulars are read first and hand it over.
    pub def fromLaps(entry: Entry, timeLimit: Duration): List[Timeline.Event] \ DbRead =
        Timeline.fromReadings({
            timeLimit     = timeLimit,
            cars          = cars(entry),
            flags         = Round.Index.flags(entry),
            overtakes     = overtakes(entry),
            inPits        = leadersInPit(entry),
            fastestLaps   = fastestLaps(entry),
            driverChanges = driverChanges(entry)
        })

    // ------------------------------------------------------------------ cars

    /// Each car that turned a lap, with the moment it last crossed the line and the
    /// lap that made it, in the order the file first showed them.
    ///
    /// A car's laps only ever run forwards, so its latest crossing is the one its
    /// last lap made, and its highest lap number is the same row's.
    def cars(entry: Entry): List[(String, Duration, Int32)] \ DbRead =
        let c = Laps.columns();
        Laps.rows(entry)
            |> Sql.groupBy(Schema.term(c#carNumber) :: Nil)
            |> Sql.orderBy(Sql.fragment(Sql.min(c#sourceRow)) :: Nil)
            |> Sql.map(row -> (row#carNumber, Sql.max(row#elapsedMs), Sql.max(row#lapNumber)))
            |> Sql.reading(match (carNumber, last, lastLap) ->
                (carNumber, Util.Duration.fromMillis(last), lastLap))
            |> Sql.selectAll

    // ----------------------------------------------------------- fastest laps

    /// Every lap faster than any its class had completed before it, in the order
    /// the laps were completed and with the file's order breaking a tie on the
    /// clock, as `Round.Index` walks the field's.
    ///
    /// Not lap 1, for the reason `Round.Index` leaves it out of the fastest lap. A
    /// lap the feed did not time is written `0.000` and is no lap at all.
    def fastestLaps(entry: Entry): List[Timeline.FastestLap] \ DbRead =
        Sql.statement(
            "WITH timed AS (SELECT ${Laps.table()}.car_number, elapsed_ms, lap_number, lap_time_ms,"
                + " MIN(lap_time_ms) OVER (PARTITION BY ${Entries.table()}.class"
                + " ORDER BY elapsed_ms, source_row"
                + " ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS standing"
                + " FROM ${classed()} WHERE lap_number > 1 AND lap_time_ms <> 0 AND ??)"
                + " SELECT %% FROM timed"
                + " WHERE standing IS NULL OR lap_time_ms < standing"
                + " ORDER BY elapsed_ms",
            Laps.scope(entry, Nil) :: Nil,
            (Sql.text("car_number"), Sql.int("elapsed_ms"), Sql.int("lap_number")))
            |> Sql.reading(match (carNumber, elapsed, lapNumber) ->
                {
                    carNumber = carNumber,
                    elapsed = Util.Duration.fromMillis(elapsed),
                    lapNumber = lapNumber
                })
            |> Sql.selectAll

    // --------------------------------------------------------- driver changes

    /// Every lap whose driver is not the one of the car's lap before it, timed at
    /// that lap before's crossing: the lap in progress from there on is the new
    /// driver's, which is when the app reads the car as theirs. Not only out-laps,
    /// though every change in the rounds loaded falls on one.
    def driverChanges(entry: Entry): List[Timeline.DriverChange] \ DbRead =
        Sql.statement(
            "WITH seated AS (SELECT car_number, driver_number,"
                + " LAG(driver_number) OVER (PARTITION BY car_number ORDER BY lap_number) AS prior,"
                + " LAG(elapsed_ms) OVER (PARTITION BY car_number ORDER BY lap_number) AS handed_at,"
                + " LAG(lap_number) OVER (PARTITION BY car_number ORDER BY lap_number) AS handed_lap"
                + " FROM ${Laps.table()} WHERE ??)"
                + " SELECT %% FROM seated"
                + " WHERE prior IS NOT NULL AND prior <> driver_number"
                + " ORDER BY handed_at",
            Laps.scope(entry, Nil) :: Nil,
            (Sql.text("car_number"), Sql.int("handed_at"), Sql.int("handed_lap")))
            |> Sql.reading(match (carNumber, elapsed, lapNumber) ->
                {
                    carNumber = carNumber,
                    elapsed = Util.Duration.fromMillis(elapsed),
                    lapNumber = lapNumber
                })
            |> Sql.selectAll

    // ------------------------------------------------------------ overtakes

    /// Where a class's lead changed hands on the track: the car that took it and
    /// the crossing that took it.
    ///
    /// The lead is a class's order at a lap boundary, read the way
    /// `Round.Laps.place` reads the field's: the first of the class's rows
    /// carrying a lap number. The top class's lead is the field's in every round
    /// loaded, so no lead is counted over the whole field beside it. Whoever led
    /// the opening lap took it from nobody, which is what `LAG` answering null is.
    ///
    /// The two windows are a query each because SQLite settles a `WHERE`
    /// before either of them: the leaders are picked out in `l`, and only then
    /// is each one asked who led the lap before.
    ///
    /// The car that lost the lead has to have crossed that boundary on the track. One
    /// that crossed it as either half of a stop was not overtaken -- the stop is
    /// `leadersInPit`'s event -- and nor was one that never crossed it, having
    /// retired.
    def overtakes(entry: Entry): List[Timeline.Overtake] \ DbRead =
        Sql.statement(
            "WITH ${crossings()}"
                + " SELECT %% FROM ("
                + " SELECT car_number, lap_number, elapsed_ms,"
                + " LAG(car_number) OVER (PARTITION BY car_class ORDER BY lap_number) AS held"
                + " FROM l WHERE rn = 1) AS led"
                + " WHERE held IS NOT NULL AND held <> car_number"
                // The lap the overtake is read on is the out-lap's own, and not the one
                // before it: a leader that came back out in front has its out-lap there,
                // and an overtake on the lap after is still one.
                + " AND EXISTS (SELECT 1 FROM l WHERE l.car_number = led.held"
                + " AND l.lap_number = led.lap_number AND NOT l.pitted)"
                + " ORDER BY elapsed_ms",
            Laps.scope(entry, Nil) :: Nil,
            (Sql.text("car_number"), Sql.int("elapsed_ms"), Sql.int("lap_number")))
            |> Sql.reading(match (carNumber, elapsed, lapNumber) ->
                {
                    carNumber = carNumber,
                    elapsed = Util.Duration.fromMillis(elapsed),
                    lapNumber = lapNumber
                })
            |> Sql.selectAll

    // ---------------------------------------------------------------- in pit

    /// Every time the car leading its class went into the pits, whether the lead
    /// changed hands over the stop or not: the crossing at which it turned down the
    /// pit lane, made by a car that led its class on that lap or the lap before it.
    /// A stop is counted at its out-lap, for `Db.Laps.pitOutLap`'s reason, and timed
    /// at its in-lap.
    def leadersInPit(entry: Entry): List[Timeline.InPit] \ DbRead =
        Sql.statement(
            "WITH ${crossings()},"
                // Who led their class on each lap. A car only ever leads its own class,
                // so a stop is matched to its car's leads by the car alone.
                + " led AS (SELECT car_number, lap_number FROM l WHERE rn = 1)"
                + " SELECT %% FROM l AS stop"
                // A stop the car in the lead made: it led the lap before its out-lap, or
                // the lap before that -- the leader that lost the lead at the crossing it
                // turned down the lane from, coming back out one lap later. Not the lap
                // before that when the lap between was an out-lap of its own: that is a
                // second stop straight after one, and the lead two laps back was lost at
                // the first.
                + " WHERE stopped AND EXISTS (SELECT 1 FROM led WHERE led.car_number = stop.car_number"
                + " AND (led.lap_number = stop.lap_number - 1"
                + " OR (led.lap_number = stop.lap_number - 2"
                + " AND NOT EXISTS (SELECT 1 FROM l AS between_ WHERE between_.car_number = stop.car_number"
                + " AND between_.lap_number = stop.lap_number - 1 AND between_.stopped))))"
                + " ORDER BY elapsed_ms",
            Laps.scope(entry, Nil) :: Nil,
            (Sql.text("car_number"), cameInAt(), cameInOn()))
            |> Sql.reading(match (carNumber, elapsed, lapNumber) ->
                {
                    carNumber = carNumber,
                    elapsed = Util.Duration.fromMillis(elapsed),
                    lapNumber = lapNumber
                })
            |> Sql.selectAll

    /// Every crossing of the round's, with its class and its place in its class's
    /// lap, under the name `l` the two readings that count what happened at a
    /// boundary correlate their subqueries on.
    def crossings(): String =
        "l AS (SELECT ${Laps.table()}.car_number, lap_number, elapsed_ms,"
            + " ${Laps.pitLap()} AS pitted, ${Laps.pitOutLap()} AS stopped,"
            + " ${Entries.table()}.class AS car_class,"
            + " ROW_NUMBER() OVER (PARTITION BY ${Entries.table()}.class, lap_number"
            + " ORDER BY elapsed_ms, source_row) AS rn"
            + " FROM ${classed()} WHERE ??)"

    /// The laps, each beside the class of the car that ran it. A lap with no row in
    /// `cars` has no class and is dropped; the load writes the cars first.
    def classed(): String =
        let laps = Laps.table();
        let cars = Cars.table();
        let entries = Entries.table();
        "${laps} JOIN ${cars} ON ${cars}.round_id = ${laps}.round_id"
            + " AND ${cars}.car_number = ${laps}.car_number"
            + " JOIN ${entries} ON ${entries}.entry_id = ${cars}.entry_id"

    /// Where the car that made the out-lap came in: of that lap and the one before
    /// it, the earlier of the crossings that are one half of a stop, which is the
    /// in-lap when the feed wrote it.
    ///
    /// Both these readings correlate on rows no source declares columns for, and read
    /// the same row, so they cannot disagree about which crossing the event fell on.
    def cameInAt(): Sel[Int32] =
        Sql.int("(SELECT l.elapsed_ms FROM l WHERE l.car_number = stop.car_number"
            + " AND l.lap_number BETWEEN stop.lap_number - 1 AND stop.lap_number"
            + " AND l.pitted ORDER BY l.lap_number ASC LIMIT 1)")

    /// Which lap the car came in on, read off the crossing `cameInAt` times.
    def cameInOn(): Sel[Int32] =
        Sql.int("(SELECT l.lap_number FROM l WHERE l.car_number = stop.car_number"
            + " AND l.lap_number BETWEEN stop.lap_number - 1 AND stop.lap_number"
            + " AND l.pitted ORDER BY l.lap_number ASC LIMIT 1)")

    // -------------------------------------------------- the laps events fell on

    /// One time of the lap an event fell on, beside the two baselines it reads
    /// against: `fastest`, the field's record as it stood the moment the event fell,
    /// and `personalBest`, this car's own up to and including that lap.
    ///
    /// No rating and no colour crosses here: what a time reads as is
    /// `Motorsport.Lap.Performance`'s, on the Elm side.
    pub type alias Rated = {
        time         = Option[Duration],
        fastest      = Option[Duration],
        personalBest = Option[Duration]
    }

    pub type alias Detail = {
        driver      = String,
        lap         = Rated,
        sectors     = List[(Sector, Rated)],
        miniSectors = Option[List[(MiniSectorId, Rated)]]
    }

    /// An event, and the lap it fell on where it fell on one.
    pub type alias Detailed = {
        event  = Timeline.Event,
        detail = Option[Detail]
    }

    /// The cells a `Detail` is made of: the lap's own times, and this car's best of
    /// each of them up to and including this lap. The two mini-sector lists are the
    /// fifteen of `Motorsport.MiniSector.all()` in track order.
    type alias Cells = {
        carNumber    = String,
        lapNumber    = Int32,
        driverNumber = Int32,
        lapTime      = Option[Int32],
        s1           = Option[Int32],
        s2           = Option[Int32],
        s3           = Option[Int32],
        miniTimes    = Option[List[Option[Int32]]],
        lapBest      = Option[Int32],
        s1Best       = Option[Int32],
        s2Best       = Option[Int32],
        s3Best       = Option[Int32],
        miniBests    = Option[List[Option[Int32]]]
    }

    /// Which lap a fastest lap was set on, which is the only lap read for its cells.
    /// The other car events name a lap too -- the one they fell on -- and are on no
    /// lap whose times are drawn.
    def lapOf(event: Timeline.Event): Option[(String, Int32)] =
        match (event#eventType, event#lap) {
            case (EventType.Of(carNumber, CarEvent.FastestLap), Some(lap)) => Some((carNumber, lap))
            case _                                                          => None
        }

    /// The laps the events fell on, keyed by the pair that names one.
    def lapCells(entry: Entry, named: List[(String, Int32)]): Map[(String, Int32), Cells] \ DbRead =
        if (List.isEmpty(named))
            Map.empty()
        else
            Sql.statement(running(), Laps.scope(entry, Nil) :: namedLaps(named) :: Nil, cellSelection())
                |> Sql.selectAll
                |> List.map(row -> ((row#carNumber, row#lapNumber), row))
                |> List.toMap

    def beside(
        seats: Round.Drivers.Seats,
        index: Index.Index,
        cells: Map[(String, Int32), Cells]
    ): Timeline.Event -> Detailed \ DbErr =
        event -> {
            event = event,
            detail = Option.flatMap(lap -> match Map.get(lap, cells) {
                case Some(r) => Some(detail(seats, index, event#elapsed, fst(lap), r))
                case None    => DbErr.raise(Db.Error.Incomplete(
                    "the timeline names lap ${snd(lap)} of car ${fst(lap)}, which the laps are not"))
            }, lapOf(event))
        }

    def detail(
        seats: Round.Drivers.Seats,
        index: Index.Index,
        at: Duration,
        carNumber: String,
        r: Cells
    ): Detail \ DbErr =
        {
            driver = Round.Drivers.nameOf(seats, carNumber, r#driverNumber),
            lap = rated(r#lapTime, Record.FastestLap, at, index, r#lapBest),
            sectors = sectorRatings(r, at, index),
            miniSectors = miniRatings(r, at, index)
        }

    def sectorRatings(r: Cells, at: Duration, index: Index.Index): List[(Sector, Rated)] =
        sectorRating(Sector.S1, r#s1, r#s1Best, at, index) ::
        sectorRating(Sector.S2, r#s2, r#s2Best, at, index) ::
        sectorRating(Sector.S3, r#s3, r#s3Best, at, index) :: Nil

    def sectorRating(
        which: Sector,
        time: Option[Int32],
        best: Option[Int32],
        at: Duration,
        index: Index.Index
    ): (Sector, Rated) =
        (which, rated(time, Record.FastestSector(which), at, index, best))

    /// The fifteen, where the round's feed measured them.
    ///
    /// The bests come back as a JSON array of the same fifteen in the same order,
    /// which is why both are read by position.
    def miniRatings(r: Cells, at: Duration, index: Index.Index): Option[List[(MiniSectorId, Rated)]] =
        match r#miniTimes {
            case None        => None
            case Some(times) =>
                let bests = match r#miniBests {
                    case Some(b) => b
                    case None    => Nil
                };
                let places = List.zipWithIndex(MiniSector.all());
                Some(places |> List.map(miniPlace(times, bests, at, index)))
        }

    /// The fifteen, each by its place on the circuit -- the subscript the array
    /// column is read at, and the index `List.zipWithIndex` counts from.
    def miniPlace(
        times: List[Option[Int32]],
        bests: List[Option[Int32]],
        at: Duration,
        index: Index.Index
    ): ((Int32, MiniSectorId)) -> (MiniSectorId, Rated) =
        place -> match place {
            case (position, which) =>
                (which, rated(
                    Option.flatten(List.nth(position, times)),
                    Record.FastestMiniSector(which),
                    at,
                    index,
                    Option.flatten(List.nth(position, bests))))
        }

    def rated(
        time: Option[Int32],
        record: Record,
        at: Duration,
        index: Index.Index,
        best: Option[Int32]
    ): Rated =
        {
            time = Option.map(Util.Duration.fromMillis, time),
            fastest = standingAt(record, at, index),
            personalBest = Option.map(Util.Duration.fromMillis, best)
        }

    /// The record as it stood when the event fell: the last change at or before it,
    /// which is the lap that took it. `Round.Index` counts a change the moment a
    /// record is beaten, so a lap is rated against the record it itself took -- as
    /// `Motorsport.BestTimes.at` reads the same changes back.
    def standingAt(record: Record, at: Duration, index: Index.Index): Option[Duration] =
        Index.changesOf(record, index)
            |> List.filter(change -> change#elapsed <= at)
            |> List.last
            |> Option.map(change -> change#time)

    /// The window, over every lap of the round.
    ///
    /// A mini-sector of a lap the feed wrote no time for is no segment of the
    /// circuit, which is why the fifteen are each guarded by `lap_time_ms <> 0` --
    /// the same reading `Round.Index` throws out of the records.
    ///
    /// The laps the events fell on are picked out outside the window: a `WHERE` of
    /// the same SELECT is settled before a window, and the best of the kept laps
    /// alone is not the best up to that lap.
    def running(): String =
        "WITH running AS (SELECT car_number, driver_number, lap_number,"
            + " NULLIF(lap_time_ms, 0) AS lap_time, s1_ms, s2_ms, s3_ms,"
            + " mini_sector_time_ms,"
            + " MIN(NULLIF(lap_time_ms, 0)) OVER w AS lap_best,"
            + " MIN(s1_ms) OVER w AS s1_best,"
            + " MIN(s2_ms) OVER w AS s2_best,"
            + " MIN(s3_ms) OVER w AS s3_best, "
            + miniWindows()
            + " FROM ${Laps.table()} WHERE ??"
            + " WINDOW w AS (PARTITION BY car_number ORDER BY lap_number"
            + " ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))"
            + " SELECT %% FROM running WHERE ??"

    /// One `MIN ... OVER w` per place on the circuit, and `json_extract` reads the
    /// array column by that same subscript.
    def miniWindows(): String =
        List.range(0, List.length(MiniSector.all()))
            |> List.map(position ->
                "MIN(CASE WHEN lap_time_ms <> 0"
                    + " THEN json_extract(mini_sector_time_ms, '$[${position}]') END) OVER w AS b${position}")
            |> List.join(", ")

    def miniBests(): String =
        List.range(0, List.length(MiniSector.all()))
            |> List.map(position -> "b${position}")
            |> List.join(", ")

    /// The laps the events fell on. A row-value `IN`, since a lap is named by a
    /// pair, and bound rather than written in: a car number came out of a feed.
    def namedLaps(named: List[(String, Int32)]): Sql.Frag =
        let placeholders = named |> List.map(_ -> "(?, ?)") |> List.join(", ");
        let params = named |> List.flatMap(match (carNumber, lapNumber) ->
            List#{Value.Text(carNumber), Value.Integer(lapNumber)});
        Sql.frag("(car_number, lap_number) IN (${placeholders})", params)

    /// A lap the events fell on, its own times and its car's best of each, the
    /// fifteen mini-sector bests gathered back into one JSON array so the reading is
    /// thirteen columns and not twenty-seven.
    def cellSelection(): Sel[Cells] =
        Sql.record({})
            |> Sql.field(Sql.text("car_number"), (r, value) -> { +carNumber = value | r })
            |> Sql.field(Sql.int("lap_number"), (r, value) -> { +lapNumber = value | r })
            |> Sql.field(Sql.int("driver_number"), (r, value) -> { +driverNumber = value | r })
            |> Sql.field(Sql.optionalInt("lap_time"), (r, value) -> { +lapTime = value | r })
            |> Sql.field(Sql.optionalInt("s1_ms"), (r, value) -> { +s1 = value | r })
            |> Sql.field(Sql.optionalInt("s2_ms"), (r, value) -> { +s2 = value | r })
            |> Sql.field(Sql.optionalInt("s3_ms"), (r, value) -> { +s3 = value | r })
            |> Sql.field(Sql.optionalIntArray("mini_sector_time_ms"),
                (r, value) -> { +miniTimes = value | r })
            |> Sql.field(Sql.optionalInt("lap_best"), (r, value) -> { +lapBest = value | r })
            |> Sql.field(Sql.optionalInt("s1_best"), (r, value) -> { +s1Best = value | r })
            |> Sql.field(Sql.optionalInt("s2_best"), (r, value) -> { +s2Best = value | r })
            |> Sql.field(Sql.optionalInt("s3_best"), (r, value) -> { +s3Best = value | r })
            |> Sql.field(Sql.optionalIntArray("json_array(${miniBests()}) AS mini_best"),
                (r, value) -> { +miniBests = value | r })

}
