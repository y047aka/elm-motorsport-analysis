/// The round's indices, read back out of the rows it was loaded into.
///
/// Which column measures a record, and which way round a time has to be to beat
/// the standing one, is settled here beside the query that counts it. What a
/// record is stays in `Motorsport.Index`.
mod Round.Index {

    use Db.Schema
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

    def scope(entry: Entry): String =
        Schema.scope(entry#season, entry#id)

    // ------------------------------------------------------- lap completions

    /// The counter reads the leading car's completed laps, so it goes up the
    /// moment the first car of the field crosses the line for a lap.
    def lapCompletions(entry: Entry): Result[String, List[(Int32, Duration)]] \ Db =
        Sql.intoRow(lap -> elapsed -> (lap, Util.Duration.fromMillis(elapsed)))
            |> Sql.pipeline(Sql.int("lap_number"))
            |> Sql.pipeline(Sql.int("MIN(elapsed_ms)"))
            |> Sql.selectAll(
                "FROM laps WHERE " + scope(entry) + " GROUP BY lap_number ORDER BY lap_number"
            )

    // ----------------------------------------------------------- best times

    /// What each record is drawn from, and which way round it is won: `1` keeps
    /// the smallest reading, `-1` the largest. A record's place in this list is
    /// the number the query labels its rows with, so the two cannot drift.
    def sources(): List[(Record, Int32, String)] =
        (Record.FastestLap, 1, "NULLIF(lap_time_ms, 0)") ::
        (Record.SlowestLap, -1, "NULLIF(lap_time_ms, 0)") ::
        (Record.FastestSector(Sector.S1), 1, "s1_ms") ::
        (Record.FastestSector(Sector.S2), 1, "s2_ms") ::
        (Record.FastestSector(Sector.S3), 1, "s3_ms") ::
        Nil

    /// The fifteen mini-sectors are one branch, `json_each` numbering them from
    /// zero as the labels carry on from `sources`.
    def miniSectorBase(): Int32 =
        List.length(sources())

    def recordOf(label: Int32): Option[Record] =
        if (label < miniSectorBase())
            List.nth(label, sources()) |> Option.map(match (record, _, _) -> record)
        else
            MiniSector.atPosition(label - miniSectorBase() + 1)
                |> Option.map(mini -> Record.FastestMiniSector(mini))

    def bestTimes(entry: Entry): Result[String, List[(Record, Change)]] \ Db =
        change()
            |> Sql.selectAllWith(
                readings(entry),
                "FROM (" + standing() + ") WHERE prev IS NULL OR t * dir < prev"
                    + " ORDER BY k, elapsed_ms, source_row"
            )

    def change(): Sel[(Record, Change)] =
        Sql.intoRow(record -> elapsed -> time -> carNumber -> lap -> driver -> (record, {
            elapsed   = Util.Duration.fromMillis(elapsed),
            time      = Util.Duration.fromMillis(time),
            carNumber = carNumber,
            lap       = lap,
            driver    = driver
        }))
            |> Sql.pipeline(Sql.int("k") |> Sql.andThen(label ->
                recordOf(label) |> Option.toOk("no record is labelled ${label}")))
            |> Sql.pipeline(Sql.int("elapsed_ms"))
            |> Sql.pipeline(Sql.int("t"))
            |> Sql.pipeline(Sql.text("car_number"))
            |> Sql.pipeline(Sql.int("lap_number"))
            |> Sql.pipeline(Sql.text("driver_name"))

    def changesOf(record: Record, changes: List[(Record, Change)]): List[Change] =
        changes |> List.filterMap(match (r, change) -> if (r == record) Some(change) else None)

    /// Every record's readings stacked into one column.
    ///
    /// The feed writes a lap it did not record as `0.000`, and the mini-sectors
    /// of such a lap are not a lap of the circuit either.
    def readings(entry: Entry): String =
        let scalar = sources()
            |> List.mapWithIndex((label, source) -> match source {
                case (_, direction, expression) => reading(entry, label, direction, expression)
            });
        let stacked = List.append(scalar, miniSectorReadings(entry) :: Nil);
        "WITH v AS (" + List.join(" UNION ALL ", stacked) + ")"

    /// Every reading with the record as it stood before it beside it, the
    /// readings walked once in the order the laps were completed.
    def standing(): String =
        "SELECT k, elapsed_ms, source_row, car_number, lap_number, driver_name, t, dir,"
            + " MIN(t * dir) OVER (PARTITION BY k ORDER BY elapsed_ms, source_row"
            + " ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev"
            + " FROM v WHERE t IS NOT NULL"

    def reading(entry: Entry, label: Int32, direction: Int32, expression: String): String =
        "SELECT elapsed_ms, source_row, car_number, lap_number, driver_name,"
            + " ${label} AS k, ${direction} AS dir, ${expression} AS t"
            + " FROM laps WHERE " + scope(entry)

    def miniSectorReadings(entry: Entry): String =
        "SELECT elapsed_ms, source_row, car_number, lap_number, driver_name,"
            + " ${miniSectorBase()} + m.key, 1, m.value"
            + " FROM laps, json_each(laps.mini_sector_time_ms) m"
            + " WHERE " + scope(entry) + " AND lap_time_ms <> 0"

}
