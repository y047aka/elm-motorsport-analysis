/// The round's timeline, both halves of it: counted out of the laps for the
/// load to write down, and read back out of the rows it wrote. The counting is
/// two readings of the laps -- each car's last moment, and each change of the
/// lead -- and what they add up to is `Motorsport.Timeline`'s.
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
            leads     = leads(entry)
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

    // ----------------------------------------------------------------- leads

    /// Each change of the lead: who took it, when, and which way it went.
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
    /// `l` is asked once more, for the lap the change is counted on, whether the
    /// car that lost the lead crossed it as half of a stop. It has that crossing
    /// already -- one row per car per lap, the leaders being the `rn = 1` ones --
    /// so which way the lead went costs no third reading of the laps.
    def leads(entry: Entry): List[(String, Duration, Timeline.Handover)] \ DbRead =
        Sql.rows(Sql.raw("(" + handedOver() + ") AS led"))
            |> Sql.using(Sql.frags(
                Sql.raw("l AS (SELECT car_number, lap_number, elapsed_ms,"
                    + " ${Laps.pitLap()} AS pitted, " + firstAcross()
                    + " FROM " + Laps.table() + " WHERE") ::
                Sql.term(Laps.inRound(entry)) ::
                Sql.raw(")") :: Nil
            ))
            |> Sql.filter(_ -> Sql.column("held IS NOT NULL AND held <> car_number"))
            |> Sql.orderBy(Sql.raw("lap_number") :: Nil)
            |> Sql.map(_ -> (Sql.text("car_number"), Sql.int("elapsed_ms"), Sql.bool(cameIn())))
            |> Sql.reading(match (carNumber, elapsed, cameInPits) ->
                (carNumber, Util.Duration.fromMillis(elapsed), handover(cameInPits)))
            |> Sql.selectAll

    def firstAcross(): String =
        "ROW_NUMBER() OVER (PARTITION BY lap_number ORDER BY elapsed_ms, source_row) AS rn"

    def handedOver(): String =
        "SELECT car_number, lap_number, elapsed_ms,"
            + " LAG(car_number) OVER (ORDER BY lap_number) AS held"
            + " FROM l WHERE rn = 1"

    /// Whether the lead went through the pits: the car holding it came in on the
    /// lap this change is counted on, so whoever stayed out is in front without
    /// having passed anyone.
    def cameIn(): String =
        "EXISTS (SELECT 1 FROM l"
            + " WHERE l.lap_number = led.lap_number"
            + " AND l.car_number = led.held AND l.pitted)"

    def handover(cameInPits: Bool): Timeline.Handover =
        if (cameInPits) Timeline.Handover.InPits else Timeline.Handover.OnTrack

}
