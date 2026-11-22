/// The round's indices, read back out of the rows it was loaded into.
///
/// Which column measures a record, and which way round a time has to be to beat
/// the standing one, is settled here beside the query that counts it. What a
/// record is stays in `Motorsport.Index`.
pub mod Round.Index {
    use Sqlitefx.DbErr
    use Sqlitefx.DbRead
    use Sqlitefx.RawSql

    use Db.LapRow.LapRow
    use Db.Laps
    use Db.Schema
    use Db.Schema.Column
    use Motorsport.Calendar.Entry
    use Motorsport.Flag.FlagShown
    use Motorsport.Index
    use Motorsport.Index.Change
    use Motorsport.Index.Record
    use Motorsport.MiniSector
    use Motorsport.Sector.Sector
    use Motorsport.Wec
    use Util.Duration.Duration

    pub def read(entry: Entry, seats: Round.Drivers.Seats): Index.Index \ DbRead + RawSql =
        let completions = lapCompletions(entry);
        let changes = bestTimes(entry, seats);
        {
            lapCompletions = completions,
            bestTimes      = Index.records() |> List.map(record -> (record, changesOf(record, changes))),
            flags          = flags(entry)
        }

    // ------------------------------------------------------- lap completions

    /// The counter reads the leading car's completed laps, so it goes up the
    /// moment the first car of the field crosses the line for a lap.
    def lapCompletions(entry: Entry): List[(Int32, Duration)] \ DbRead + RawSql =
        Laps.rows(entry)
            |> Sql.groupBy(Schema.term(Laps.columns()#lapNumber) :: Nil)
            |> Sql.orderBy(Schema.term(Laps.columns()#lapNumber) :: Nil)
            |> Sql.map(c -> (c#lapNumber, Sql.min(c#elapsedMs)))
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
    pub def flags(entry: Entry): List[FlagShown] \ DbRead + RawSql =
        let green = Wec.flagToString(Wec.Flag.Green);
        let finish = Wec.flagToString(Wec.Flag.Finish);
        let c = Laps.columns();
        Sql.statement(
            "WITH shown AS (SELECT elapsed_ms, flag_at_fl," ::
            "COALESCE(LAG(flag_at_fl) OVER (ORDER BY elapsed_ms, source_row), '${green}') AS prior" ::
            "FROM ${Laps.table()} WHERE flag_at_fl <> '${finish}' AND {{scope}})" ::
            "SELECT %% FROM shown WHERE flag_at_fl <> prior ORDER BY elapsed_ms" :: Nil,
            Map#{ "scope" => Laps.scope(entry, Nil) },
            (c#flagAtFl, c#elapsedMs))
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
        let c = Laps.columns();
        (Record.FastestLap, "NULLIF(${c#lapTimeMs}, 0)", notLapOne() :: Nil) ::
        (Record.FastestSector(Sector.S1), "${c#s1Ms}", notLapOne() :: Nil) ::
        (Record.FastestSector(Sector.S2), "${c#s2Ms}", Nil) ::
        (Record.FastestSector(Sector.S3), "${c#s3Ms}", Nil) ::
        Nil

    /// The five columns every reading carries, beside the reading itself. A statement
    /// written out interpolates these, so a name is spelled here once.
    pub type alias Walked = {
        elapsedMs    = Column[LapRow, Int32],
        sourceRow    = Column[LapRow, Int32],
        carNumber    = Column[LapRow, String],
        lapNumber    = Column[LapRow, Int32],
        driverNumber = Column[LapRow, Int32],
        t            = Column[LapRow, Int32]
    }

    def walked(): Walked =
        let c = Laps.columns();
        {
            elapsedMs    = c#elapsedMs,
            sourceRow    = c#sourceRow,
            carNumber    = c#carNumber,
            lapNumber    = c#lapNumber,
            driverNumber = c#driverNumber,
            t            = Schema.derived("t", "int", Sql.int)
        }

    def notLapOne(): Sql.Expr[Bool] =
        Sql.ne(Schema.expr(Laps.columns()#lapNumber), Sql.i32(1))

    def bestTimes(entry: Entry, seats: Round.Drivers.Seats): List[(Record, Change)] \ DbRead + RawSql =
        let w = walked();
        let (readings, record) = Sql.unionAllTagged("k", branches(entry));
        Sql.statement(
            // Every reading with the record as it stood before it beside it, the
            // readings walked once in the order the laps were completed.
            "WITH v AS ({{readings}})" ::
            "SELECT %% FROM (SELECT k, ${w#elapsedMs}, ${w#sourceRow}, ${w#carNumber}," ::
            "${w#lapNumber}, ${w#driverNumber}, ${w#t}," ::
            "MIN(${w#t}) OVER (PARTITION BY k ORDER BY ${w#elapsedMs}, ${w#sourceRow}" ::
            "ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev" ::
            "FROM v WHERE ${w#t} IS NOT NULL)" ::
            "WHERE prev IS NULL OR ${w#t} < prev" ::
            "ORDER BY k, ${w#elapsedMs}, ${w#sourceRow}" :: Nil,
            Map#{ "readings" => readings },
            (record, w#elapsedMs, w#t, w#carNumber, w#lapNumber, w#driverNumber))
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

    def branches(entry: Entry): List[Sql.Branch[Record]] \ DbErr =
        let scalar = sources() |> List.map(match (record, expression, predicates) ->
            Sql.Branch.One(record, reading(entry, expression, predicates)));
        List.append(scalar, miniSectorBranch(entry) :: Nil)

    /// The fifteen mini-sectors are one arm, `json_each` numbering them from
    /// zero where `Motorsport.MiniSector.positionOf` counts from one.
    def miniSectorBranch(entry: Entry): Sql.Branch[Record] \ DbErr =
        Sql.Branch.Many(
            {
                span   = List.length(MiniSector.all()),
                number = Sql.column("m.key"),
                tagOf  = key -> MiniSector.atPosition(key + 1)
                    |> Option.map(mini -> Record.FastestMiniSector(mini))
            },
            miniSectorReadings(entry)
        )

    def reading(entry: Entry, expression: String, predicates: List[Sql.Expr[Bool]]): Sql.Frag \ DbErr =
        let w = walked();
        Sql.spliced(
            "${w#elapsedMs}, ${w#sourceRow}, ${w#carNumber}, ${w#lapNumber}, ${w#driverNumber}," ::
            "${expression} AS ${w#t} FROM ${Laps.table()} WHERE {{scope}}" :: Nil,
            Map#{ "scope" => Laps.scope(entry, predicates) })

    /// The feed writes a lap it did not record as `0.000`, and the mini-sectors
    /// of such a lap are not a lap of the circuit either.
    def miniSectorReadings(entry: Entry): Sql.Frag \ DbErr =
        let w = walked();
        let c = Laps.columns();
        Sql.spliced(
            "${w#elapsedMs}, ${w#sourceRow}, ${w#carNumber}, ${w#lapNumber}, ${w#driverNumber}, m.value" ::
            "FROM ${Laps.table()}" ::
            ", json_each(${Laps.table()}.${c#miniSectorTimeMs}) m WHERE {{scope}}" :: Nil,
            Map#{ "scope" =>
                Laps.scope(entry, Sql.ne(Schema.expr(Laps.columns()#lapTimeMs), Sql.i32(0)) :: Nil) })

}
