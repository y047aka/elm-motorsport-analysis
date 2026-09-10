/// The round's timeline, both halves of it: counted out of the laps for the
/// load to write down, and read back out of the rows it wrote.
///
/// The counting is three readings of the laps -- each car's first and last
/// moment, the stops, and each change of the lead -- and what they add up to is
/// `Motorsport.Timeline`'s. Only the load counts them: a round written out or
/// served is read from `timeline_events`, where the weighing is already done.
mod Round.Timeline {

    use Db.Laps
    use Db.Schema
    use Db.TimelineEvents
    use Db.TimelineEvents.EventRow
    use Motorsport.Calendar.Entry
    use Motorsport.Timeline
    use Util.Duration.Duration

    /// The round's timeline, in time order, and in the order the load numbered
    /// them where two of them share an instant.
    ///
    /// Sorted rather than read in the key's order, so that a row corrected in
    /// SQL comes back where its new moment puts it rather than where its old
    /// one did.
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
            stops     = stops(entry),
            leads     = leads(entry)
        })

    // ------------------------------------------------------------------ cars

    /// Each car that took the start, with the moment it last crossed the line,
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

    // ----------------------------------------------------------------- stops

    /// One row per stop: the lap it ended on, when the car came back out, and
    /// how long it was in.
    def stops(entry: Entry): List[(String, Int32, Duration, Duration)] \ DbRead =
        let c = Laps.columns();
        Laps.rows(entry)
            |> Sql.filter(row -> Sql.isNotNull(Schema.expr(row#pitTimeMs)))
            |> Sql.orderBy(Schema.term(c#elapsedMs) :: Schema.term(c#sourceRow) :: Nil)
            |> Sql.map(row -> (row#carNumber, row#lapNumber, row#elapsedMs, row#pitTimeMs))
            |> Sql.selectAll
            |> List.filterMap(stop)

    def stop(row: (String, Int32, Int32, Option[Int32])): Option[(String, Int32, Duration, Duration)] =
        match row {
            case (carNumber, lapNumber, elapsed, Some(duration)) => Some((
                carNumber,
                lapNumber,
                Util.Duration.fromMillis(elapsed),
                Util.Duration.fromMillis(duration)
            ))
            case _ => None
        }

    // ----------------------------------------------------------------- leads

    /// Each change of the lead, and who took it.
    ///
    /// The lead is the field's order at a lap boundary, which is what
    /// `Round.Laps.placeInField` counts, so it is read the same way: the first
    /// of the round's rows carrying a lap number. Whoever led the opening lap
    /// took it from nobody, which is what `LAG` answering null is.
    ///
    /// The two windows are a query each because SQLite settles a `WHERE`
    /// before either of them: the leaders are picked out in `l`, and only then
    /// is each one asked who led the lap before.
    def leads(entry: Entry): List[(String, Duration)] \ DbRead =
        Sql.rows(Sql.raw("(" + handedOver() + ")"))
            |> Sql.using(Sql.frags(
                Sql.raw("l AS (SELECT car_number, lap_number, elapsed_ms, " + firstAcross()
                    + " FROM " + Laps.table() + " WHERE") ::
                Sql.term(Laps.inRound(entry)) ::
                Sql.raw(")") :: Nil
            ))
            |> Sql.filter(_ -> Sql.column("held IS NOT NULL AND held <> car_number"))
            |> Sql.orderBy(Sql.raw("lap_number") :: Nil)
            |> Sql.map(_ -> (Sql.text("car_number"), Sql.int("elapsed_ms")))
            |> Sql.reading(match (carNumber, elapsed) -> (carNumber, Util.Duration.fromMillis(elapsed)))
            |> Sql.selectAll

    def firstAcross(): String =
        "ROW_NUMBER() OVER (PARTITION BY lap_number ORDER BY elapsed_ms, source_row) AS rn"

    def handedOver(): String =
        "SELECT car_number, lap_number, elapsed_ms,"
            + " LAG(car_number) OVER (ORDER BY lap_number) AS held"
            + " FROM l WHERE rn = 1"

}
