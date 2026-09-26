/// The round's indices, read back out of the rows it was loaded into.
///
/// Which column measures a record, and which way round a time has to be to beat
/// the standing one, is settled here beside the query that counts it. What a
/// record is stays in `Motorsport.Index`.
pub mod Round.Index {

    use Db.Laps
    use Db.Schema
    use Motorsport.Calendar.Entry
    use Motorsport.Flag.FlagShown
    use Motorsport.Index
    use Motorsport.Index.Change
    use Motorsport.Index.Record
    use Motorsport.MiniSector
    use Motorsport.Sector.Sector
    use Motorsport.Wec
    use Util.Duration.Duration

    pub def read(entry: Entry, seats: Round.Drivers.Seats): Index.Index \ DbRead =
        let completions = lapCompletions(entry);
        let changes = bestTimes(entry, seats);
        {
            lapCompletions = completions,
            bestTimes      = Index.records() |> List.map(record -> (record, changesOf(record, changes))),
            flags          = flags(entry)
        }

    /// The round's rows as a fragment, for the arms that read them from
    /// inside one of their own.
    def where_(entry: Entry, predicates: List[Sql.Expr[Bool]]): Sql.Frag =
        Sql.term(Sql.every(Laps.inRound(entry) :: predicates))

    // ------------------------------------------------------- lap completions

    /// The counter reads the leading car's completed laps, so it goes up the
    /// moment the first car of the field crosses the line for a lap.
    def lapCompletions(entry: Entry): List[(Int32, Duration)] \ DbRead =
        Laps.rows(entry)
            |> Sql.groupBy(Schema.term(Laps.columns()#lapNumber) :: Nil)
            |> Sql.orderBy(Schema.term(Laps.columns()#lapNumber) :: Nil)
            |> Sql.map(c -> (c#lapNumber, Sql.int("MIN(elapsed_ms)")))
            |> Sql.reading(match (lap, elapsed) -> (lap, Util.Duration.fromMillis(elapsed)))
            |> Sql.selectAll

    // ------------------------------------------------------------------ flags

    /// Every crossing whose flag is not the one the crossing before it read, over
    /// the whole field in the order the line saw them. The race starts green, so a
    /// start behind the safety car is a change at the first crossing. The finish's
    /// own flag is no change: each car's is its `Finished`.
    ///
    /// Counted here for the summary, and handed to `Round.Timeline` for the
    /// flag events it writes at the load.
    pub def flags(entry: Entry): List[FlagShown] \ DbRead =
        let green = Wec.flagToString(Wec.Flag.Green);
        let finish = Wec.flagToString(Wec.Flag.Finish);
        Sql.rows(Sql.raw("shown"))
            |> Sql.using(Sql.frags(
                Sql.raw("shown AS (SELECT elapsed_ms, flag_at_fl,"
                    + " COALESCE(LAG(flag_at_fl) OVER (ORDER BY elapsed_ms, source_row), '${green}') AS prior"
                    + " FROM " + Laps.table() + " WHERE flag_at_fl <> '${finish}' AND") ::
                Sql.term(Laps.inRound(entry)) ::
                Sql.raw(")") :: Nil
            ))
            |> Sql.filter(_ -> Sql.column("flag_at_fl <> prior"))
            |> Sql.orderBy(Sql.raw("elapsed_ms") :: Nil)
            |> Sql.map(_ -> (Sql.text("flag_at_fl"), Sql.int("elapsed_ms")))
            |> Sql.selectAll
            |> List.filterMap(match (flag, elapsed) ->
                Wec.flagFromString(flag)
                    |> Option.flatMap(Motorsport.Flag.fromFeed)
                    |> Option.map(shown -> { flag = shown, elapsed = Util.Duration.fromMillis(elapsed) }))

    // ----------------------------------------------------------- best times

    /// What each record is drawn from, and which laps. Every one of them is won
    /// by the smallest reading, which is what lets `standing` find them all in
    /// one running minimum.
    ///
    /// Lap 1's S1, and so its time, is over a shorter stretch than any later lap's:
    /// at Fuji, Spa and Bahrain the leader's beats every later S1 by 0.6 to 1.7
    /// seconds. Its S2, its S3 and its mini-sectors are a lap's like any other.
    def sources(): List[(Record, String, List[Sql.Expr[Bool]])] =
        (Record.FastestLap, "NULLIF(lap_time_ms, 0)", notLapOne() :: Nil) ::
        (Record.FastestSector(Sector.S1), "s1_ms", notLapOne() :: Nil) ::
        (Record.FastestSector(Sector.S2), "s2_ms", Nil) ::
        (Record.FastestSector(Sector.S3), "s3_ms", Nil) ::
        Nil

    def notLapOne(): Sql.Expr[Bool] =
        Sql.ne(Schema.expr(Laps.columns()#lapNumber), Sql.i32(1))

    def bestTimes(entry: Entry, seats: Round.Drivers.Seats): List[(Record, Change)] \ DbRead =
        let (readings, record) = Sql.unionAllTagged("k", branches(entry));
        Sql.rows(Sql.raw("(" + standing() + ")"))
            |> Sql.using(Sql.frags(Sql.raw("v AS (") :: readings :: Sql.raw(")") :: Nil))
            |> Sql.filter(_ -> Sql.column("prev IS NULL OR t < prev"))
            |> Sql.orderBy(Sql.raw("k") :: Sql.raw("elapsed_ms") :: Sql.raw("source_row") :: Nil)
            |> Sql.map(_ -> (
                record,
                Sql.int("elapsed_ms"),
                Sql.int("t"),
                Sql.text("car_number"),
                Sql.int("lap_number"),
                Sql.int("driver_number")
            ))
            |> Sql.selectAll
            |> List.map(change(seats))

    def change(seats: Round.Drivers.Seats): ((Record, Int32, Int32, String, Int32, Int32)) -> (Record, Change) \ DbErr =
        row -> match row {
            case (record, elapsed, time, carNumber, lap, driverNumber) => (record, {
                elapsed   = Util.Duration.fromMillis(elapsed),
                time      = Util.Duration.fromMillis(time),
                carNumber = carNumber,
                lap       = lap,
                driver    = Round.Drivers.nameOf(seats, carNumber, driverNumber)
            })
        }

    def changesOf(record: Record, changes: List[(Record, Change)]): List[Change] =
        changes |> List.filterMap(match (r, change) -> if (r == record) Some(change) else None)

    def branches(entry: Entry): List[Sql.Branch[Record]] =
        let scalar = sources() |> List.map(match (record, expression, predicates) ->
            Sql.Branch.One(record, reading(entry, expression, predicates)));
        List.append(scalar, miniSectorBranch(entry) :: Nil)

    /// The fifteen mini-sectors are one arm, `json_each` numbering them from
    /// zero where `Motorsport.MiniSector.positionOf` counts from one.
    def miniSectorBranch(entry: Entry): Sql.Branch[Record] =
        Sql.Branch.Many(
            {
                span   = List.length(MiniSector.all()),
                number = Sql.column("m.key"),
                tagOf  = key -> MiniSector.atPosition(key + 1)
                    |> Option.map(mini -> Record.FastestMiniSector(mini))
            },
            miniSectorReadings(entry)
        )

    /// Every reading with the record as it stood before it beside it, the
    /// readings walked once in the order the laps were completed.
    def standing(): String =
        "SELECT k, elapsed_ms, source_row, car_number, lap_number, driver_number, t,"
            + " MIN(t) OVER (PARTITION BY k ORDER BY elapsed_ms, source_row"
            + " ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev"
            + " FROM v WHERE t IS NOT NULL"

    def reading(entry: Entry, expression: String, predicates: List[Sql.Expr[Bool]]): Sql.Frag =
        Sql.frags(
            Sql.raw("elapsed_ms, source_row, car_number, lap_number, driver_number,"
                + " ${expression} AS t"
                + " FROM " + Laps.table() + " WHERE") ::
            where_(entry, predicates) :: Nil
        )

    /// The feed writes a lap it did not record as `0.000`, and the mini-sectors
    /// of such a lap are not a lap of the circuit either.
    def miniSectorReadings(entry: Entry): Sql.Frag =
        Sql.frags(
            Sql.raw("elapsed_ms, source_row, car_number, lap_number, driver_number, m.value"
                + " FROM " + Laps.table()
                + ", json_each(" + Laps.table() + ".mini_sector_time_ms) m"
                + " WHERE") ::
            where_(entry, Sql.ne(Schema.expr(Laps.columns()#lapTimeMs), Sql.i32(0)) :: Nil) :: Nil
        )

}
