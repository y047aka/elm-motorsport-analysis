/// The round's timeline, both halves of it: counted out of the laps for the
/// load to write down, and read back out of the rows it wrote. The counting is
/// a reading of the laps per kind of event, and what they add up to is
/// `Motorsport.Timeline`'s.
pub mod Round.Timeline {

    use Db.Cars
    use Db.Entries
    use Db.Entries.EntryRow
    use Db.LapRow.LapRow
    use Db.Laps
    use Db.Schema
    use Db.Schema.Column
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
        let c = Laps.columns();
        Sql.statement(
            "WITH timed AS (SELECT ${Laps.table()}.car_number, elapsed_ms, lap_number, lap_time_ms,"
                + " MIN(lap_time_ms) OVER (PARTITION BY ${Entries.table()}.class"
                + " ORDER BY elapsed_ms, source_row"
                + " ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS standing"
                + " FROM ${classed()} WHERE lap_number > 1 AND lap_time_ms <> 0 AND {{scope}})"
                + " SELECT %% FROM timed"
                + " WHERE standing IS NULL OR lap_time_ms < standing"
                + " ORDER BY elapsed_ms",
            Map#{ "scope" => Laps.scope(entry, Nil) },
            (c#carNumber, c#elapsedMs, c#lapNumber))
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
        let c = Laps.columns();
        let handed = {
            at  = Schema.derived("handed_at", "int", Sql.int),
            lap = Schema.derived("handed_lap", "int", Sql.int)
        };
        Sql.statement(
            "WITH seated AS (SELECT car_number, driver_number,"
                + " LAG(driver_number) OVER (PARTITION BY car_number ORDER BY lap_number) AS prior,"
                + " LAG(elapsed_ms) OVER (PARTITION BY car_number ORDER BY lap_number) AS handed_at,"
                + " LAG(lap_number) OVER (PARTITION BY car_number ORDER BY lap_number) AS handed_lap"
                + " FROM ${Laps.table()} WHERE {{scope}})"
                + " SELECT %% FROM seated"
                + " WHERE prior IS NOT NULL AND prior <> driver_number"
                + " ORDER BY handed_at",
            Map#{ "scope" => Laps.scope(entry, Nil) },
            (c#carNumber, handed#at, handed#lap))
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
        let x = crossings();
        let l = seen("l", x);
        let led = seen("led", x);
        let held = Schema.qualified("led", held());
        Sql.statement(
            "WITH ${crossed(x)}"
                + " SELECT %% FROM ("
                + " SELECT ${l#carNumber}, ${l#lapNumber}, ${l#elapsedMs},"
                + " ${Sql.sqlOf(Sql.fragment(Sql.lag(l#carNumber, classLeads(l))))} AS ${heldName()}"
                + " FROM ${l#table} WHERE ${l#place} = 1) AS ${led#table}"
                + " WHERE ${held} IS NOT NULL AND ${held} <> ${led#carNumber}"
                // The lap the overtake is read on is the out-lap's own, and not the one
                // before it: a leader that came back out in front has its out-lap there,
                // and an overtake on the lap after is still one.
                + " AND EXISTS (SELECT 1 FROM ${l#table}"
                + " WHERE ${l#carNumber} = ${held}"
                + " AND ${l#lapNumber} = ${led#lapNumber} AND NOT ${l#pitted})"
                + " ORDER BY ${led#elapsedMs}",
            Map#{ "scope" => Laps.scope(entry, Nil) },
            (led#carNumber, led#elapsedMs, led#lapNumber))
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
        let x = crossings();
        let l = seen("l", x);
        let led = seen("led", x);
        let stop = seen("stop", x);
        let between = seen("between_", x);
        Sql.statement(
            "WITH ${crossed(x)},"
                // Who led their class on each lap. A car only ever leads its own class,
                // so a stop is matched to its car's leads by the car alone.
                + " ${led#table} AS (SELECT ${l#carNumber}, ${l#lapNumber}"
                + " FROM ${l#table} WHERE ${l#place} = 1)"
                + " SELECT %% FROM ${l#table} AS ${stop#table}"
                // A stop the car in the lead made: it led the lap before its out-lap, or
                // the lap before that -- the leader that lost the lead at the crossing it
                // turned down the lane from, coming back out one lap later. Not the lap
                // before that when the lap between was an out-lap of its own: that is a
                // second stop straight after one, and the lead two laps back was lost at
                // the first.
                + " WHERE ${stop#stopped} AND EXISTS (SELECT 1 FROM ${led#table}"
                + " WHERE ${led#carNumber} = ${stop#carNumber}"
                + " AND (${led#lapNumber} = ${stop#lapNumber} - 1"
                + " OR (${led#lapNumber} = ${stop#lapNumber} - 2"
                + " AND NOT EXISTS (SELECT 1 FROM ${l#table} AS ${between#table}"
                + " WHERE ${between#carNumber} = ${stop#carNumber}"
                + " AND ${between#lapNumber} = ${stop#lapNumber} - 1"
                + " AND ${between#stopped}))))"
                + " ORDER BY ${stop#elapsedMs}",
            Map#{ "scope" => Laps.scope(entry, Nil) },
            (stop#carNumber, cameInAt(stop), cameInOn(stop)))
            |> Sql.reading(match (carNumber, elapsed, lapNumber) ->
                {
                    carNumber = carNumber,
                    elapsed = Util.Duration.fromMillis(elapsed),
                    lapNumber = lapNumber
                })
            |> Sql.selectAll

    /// One crossing of the round, with its car's class and its place in its class's
    /// lap. The common table expression below writes these names and the readings
    /// that correlate on it read them, so a name is spelled once.
    pub type alias Crossings = {
        table     = String,
        carNumber = Column[LapRow, String],
        lapNumber = Column[LapRow, Int32],
        elapsedMs = Column[LapRow, Int32],
        pitted    = Column[LapRow, Bool],
        stopped   = Column[LapRow, Bool],
        carClass  = Column[EntryRow, String],
        place     = Column[LapRow, Int32]
    }

    /// The crossings as `l` declares them: three are `laps`' own columns, four are
    /// what the expression makes up, and none of them is qualified yet.
    def crossings(): Crossings =
        let c = Laps.columns();
        {
            table     = "l",
            carNumber = c#carNumber,
            lapNumber = c#lapNumber,
            elapsedMs = c#elapsedMs,
            pitted    = Schema.derived("pitted", "int not null", Sql.bool),
            stopped   = Schema.derived("stopped", "int not null", Sql.bool),
            carClass  = Schema.derived("car_class", "text not null", Sql.text),
            place     = Schema.derived("rn", "int not null", Sql.int)
        }

    /// The crossings under the name one of the sources gives them.
    def seen(source: String, c: Crossings): Crossings =
        {
            table     = source,
            carNumber = Schema.qualified(source, c#carNumber),
            lapNumber = Schema.qualified(source, c#lapNumber),
            elapsedMs = Schema.qualified(source, c#elapsedMs),
            pitted    = Schema.qualified(source, c#pitted),
            stopped   = Schema.qualified(source, c#stopped),
            carClass  = Schema.qualified(source, c#carClass),
            place     = Schema.qualified(source, c#place)
        }

    /// Who led their class on each lap, under the name `overtakes` gives it.
    def held(): Column[LapRow, String] =
        Schema.derived("held", "text", Sql.text)

    def heldName(): String =
        Schema.name(held())

    /// The crossings written out. `{{scope}}` is where the round's rows go, bound.
    def crossed(c: Crossings): String =
        let e = Entries.columns();
        "${c#table} AS (SELECT ${Laps.table()}.${c#carNumber}, ${c#lapNumber}, ${c#elapsedMs},"
            + " ${Laps.pitLap()} AS ${c#pitted}, ${Laps.pitOutLap()} AS ${c#stopped},"
            + " ${Entries.table()}.${Schema.name(e#carClass)} AS ${c#carClass},"
            + " ${Sql.sqlOf(Sql.fragment(Sql.rowNumber(firstAcross(c))))} AS ${c#place}"
            + " FROM ${classed()} WHERE {{scope}})"

    /// Who crossed the line first in their class on that lap.
    def firstAcross(c: Crossings): Sql.Window =
        let l = Laps.columns();
        Sql.window(
            Schema.term(Schema.qualified(Entries.table(), Entries.columns()#carClass)) ::
            Schema.term(c#lapNumber) :: Nil,
            Schema.term(l#elapsedMs) :: Schema.term(l#sourceRow) :: Nil,
            None
        )

    /// The order a class's leads were taken in: its own laps, in the order they were
    /// run.
    def classLeads(c: Crossings): Sql.Window =
        Sql.window(Schema.term(c#carClass) :: Nil, Schema.term(c#lapNumber) :: Nil, None)

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
    /// Both these readings correlate on the crossings from another `def`, and read
    /// the same row, so they cannot disagree about which crossing the event fell on.
    def cameInAt(stop: Crossings): Sel[Int32] =
        let l = seen("l", crossings());
        Sql.int("(SELECT ${l#elapsedMs} FROM ${l#table}"
            + " WHERE ${l#carNumber} = ${stop#carNumber}"
            + " AND ${l#lapNumber} BETWEEN ${stop#lapNumber} - 1 AND ${stop#lapNumber}"
            + " AND ${l#pitted} ORDER BY ${l#lapNumber} ASC LIMIT 1)")

    /// Which lap the car came in on, read off the crossing `cameInAt` times.
    def cameInOn(stop: Crossings): Sel[Int32] =
        let l = seen("l", crossings());
        Sql.int("(SELECT ${l#lapNumber} FROM ${l#table}"
            + " WHERE ${l#carNumber} = ${stop#carNumber}"
            + " AND ${l#lapNumber} BETWEEN ${stop#lapNumber} - 1 AND ${stop#lapNumber}"
            + " AND ${l#pitted} ORDER BY ${l#lapNumber} ASC LIMIT 1)")

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
            Sql.statement(
                running(),
                Map#{
                    "scope" => Laps.scope(entry, Nil),
                    "laps"  => namedLaps(named)
                },
                cellSelection())
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
            + " FROM ${Laps.table()} WHERE {{scope}}"
            + " WINDOW w AS (PARTITION BY car_number ORDER BY lap_number"
            + " ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))"
            + " SELECT %% FROM running WHERE {{laps}}"

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
        let c = Laps.columns();
        Sql.record({})
            |> Sql.field(c#carNumber, (r, value) -> { +carNumber = value | r })
            |> Sql.field(c#lapNumber, (r, value) -> { +lapNumber = value | r })
            |> Sql.field(c#driverNumber, (r, value) -> { +driverNumber = value | r })
            |> Sql.field(Sql.optionalInt("lap_time"), (r, value) -> { +lapTime = value | r })
            |> Sql.field(c#s1Ms, (r, value) -> { +s1 = value | r })
            |> Sql.field(c#s2Ms, (r, value) -> { +s2 = value | r })
            |> Sql.field(c#s3Ms, (r, value) -> { +s3 = value | r })
            |> Sql.field(c#miniSectorTimeMs, (r, value) -> { +miniTimes = value | r })
            |> Sql.field(Sql.optionalInt("lap_best"), (r, value) -> { +lapBest = value | r })
            |> Sql.field(Sql.optionalInt("s1_best"), (r, value) -> { +s1Best = value | r })
            |> Sql.field(Sql.optionalInt("s2_best"), (r, value) -> { +s2Best = value | r })
            |> Sql.field(Sql.optionalInt("s3_best"), (r, value) -> { +s3Best = value | r })
            |> Sql.field(Sql.optionalIntArray("json_array(${miniBests()}) AS mini_best"),
                (r, value) -> { +miniBests = value | r })

}
