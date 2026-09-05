/// The round's indices, read back out of the rows it was loaded into.
///
/// Which column measures a record, and which way round a time has to be to beat
/// the standing one, is settled here beside the query that counts it. What a
/// record is stays in `Motorsport.Index`.
mod Round.Index {

    use Db.Laps
    use Sql.Sel
    use Motorsport.Calendar.Entry
    use Motorsport.Index
    use Motorsport.Index.Change
    use Motorsport.Index.Record
    use Motorsport.MiniSector
    use Motorsport.Sector.Sector
    use Util.Duration.Duration

    pub def read(entry: Entry): Result[String, Index.Index] \ Db =
        forM(
            completions <- lapCompletions(entry);
            changes     <- bestTimes(entry)
        ) yield {
            lapCompletions = completions,
            bestTimes      = Index.records() |> List.map(record -> (record, changesOf(record, changes)))
        }

    def scope(entry: Entry): Sql.Expr[Bool] =
        Laps.scope(entry#season, entry#id)

    /// The round's rows as a fragment, for the arms that read them from
    /// inside one of their own.
    def where_(entry: Entry, predicates: List[Sql.Expr[Bool]]): Sql.Frag =
        Sql.term(Sql.every(scope(entry) :: predicates))

    // ------------------------------------------------------- lap completions

    /// The counter reads the leading car's completed laps, so it goes up the
    /// moment the first car of the field crosses the line for a lap.
    def lapCompletions(entry: Entry): Result[String, List[(Int32, Duration)]] \ Db =
        Sql.rows(Sql.raw(Laps.table()))
            |> Sql.filter(scope(entry))
            |> Sql.groupBy(Laps.term(Laps.lapNumber()) :: Nil)
            |> Sql.orderBy(Laps.term(Laps.lapNumber()) :: Nil)
            |> Sql.map(
                Sql.intoRow(lap -> elapsed -> (lap, Util.Duration.fromMillis(elapsed)))
                    |> Sql.pipeline(Laps.read(Laps.lapNumber()))
                    |> Sql.pipeline(Sql.int("MIN(elapsed_ms)"))
            )
            |> Sql.selectAll

    // ----------------------------------------------------------- best times

    /// What each record is drawn from, and which way round it is won: `1` keeps
    /// the smallest reading, `-1` the largest.
    def sources(): List[(Record, Int32, String)] =
        (Record.FastestLap, 1, "NULLIF(lap_time_ms, 0)") ::
        (Record.SlowestLap, -1, "NULLIF(lap_time_ms, 0)") ::
        (Record.FastestSector(Sector.S1), 1, "s1_ms") ::
        (Record.FastestSector(Sector.S2), 1, "s2_ms") ::
        (Record.FastestSector(Sector.S3), 1, "s3_ms") ::
        Nil

    def bestTimes(entry: Entry): Result[String, List[(Record, Change)]] \ Db =
        let (readings, record) = Sql.unionAllTagged("k", branches(entry));
        Sql.rows(Sql.raw("(" + standing() + ")"))
            |> Sql.using(Sql.frags(Sql.raw("v AS (") :: readings :: Sql.raw(")") :: Nil))
            |> Sql.filter(Sql.column("prev IS NULL OR t * dir < prev"))
            |> Sql.orderBy(Sql.raw("k") :: Sql.raw("elapsed_ms") :: Sql.raw("source_row") :: Nil)
            |> Sql.map(change(record))
            |> Sql.selectAll

    def change(record: Sel[Record]): Sel[(Record, Change)] =
        Sql.intoRow(rec -> elapsed -> time -> carNumber -> lap -> driver -> (rec, {
            elapsed   = Util.Duration.fromMillis(elapsed),
            time      = Util.Duration.fromMillis(time),
            carNumber = carNumber,
            lap       = lap,
            driver    = driver
        }))
            |> Sql.pipeline(record)
            |> Sql.pipeline(Sql.int("elapsed_ms"))
            |> Sql.pipeline(Sql.int("t"))
            |> Sql.pipeline(Sql.text("car_number"))
            |> Sql.pipeline(Sql.int("lap_number"))
            |> Sql.pipeline(Sql.text("driver_name"))

    def changesOf(record: Record, changes: List[(Record, Change)]): List[Change] =
        changes |> List.filterMap(match (r, change) -> if (r == record) Some(change) else None)

    def branches(entry: Entry): List[Sql.Branch[Record]] =
        let scalar = sources() |> List.map(match (record, direction, expression) ->
            Sql.Branch.One(record, reading(entry, direction, expression)));
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
        "SELECT k, elapsed_ms, source_row, car_number, lap_number, driver_name, t, dir,"
            + " MIN(t * dir) OVER (PARTITION BY k ORDER BY elapsed_ms, source_row"
            + " ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev"
            + " FROM v WHERE t IS NOT NULL"

    def reading(entry: Entry, direction: Int32, expression: String): Sql.Frag =
        Sql.frags(
            Sql.raw("elapsed_ms, source_row, car_number, lap_number, driver_name,"
                + " ${direction} AS dir, ${expression} AS t"
                + " FROM " + Laps.table() + " WHERE") ::
            where_(entry, Nil) :: Nil
        )

    /// The feed writes a lap it did not record as `0.000`, and the mini-sectors
    /// of such a lap are not a lap of the circuit either.
    def miniSectorReadings(entry: Entry): Sql.Frag =
        Sql.frags(
            Sql.raw("elapsed_ms, source_row, car_number, lap_number, driver_name, 1, m.value"
                + " FROM " + Laps.table()
                + ", json_each(" + Laps.table() + ".mini_sector_time_ms) m"
                + " WHERE") ::
            where_(entry, Sql.ne(Laps.expr(Laps.lapTimeMs()), Sql.i32(0)) :: Nil) :: Nil
        )

}
