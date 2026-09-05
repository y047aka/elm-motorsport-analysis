/// The round's laps, read back out of the rows it was loaded into.
mod Round.Laps {

    use Db.LapRow
    use Db.Laps.Columns
    use Db.Schema
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawLap

    /// Whether a run has loaded the round, asked rather than read back: a
    /// summary needs the answer and not the laps.
    pub def loaded(entry: Entry): Result[String, Bool] \ Db =
        laps(entry)
            |> Sql.limit(1)
            |> Sql.map(Sql.int("1"))
            |> Sql.selectAll
            |> Result.map(found -> not List.isEmpty(found))

    pub def read(entry: Entry): Result[String, List[RawLap]] \ Db =
        forM(
            lapRows <- laps(entry)
                |> Sql.orderBy(Columns.term(Columns.sourceRow()) :: Nil)
                |> Sql.map(LapRow.selection())
                |> Sql.selectAll;
            rawLaps <- Result.traverse(LapRow.toRawLap, lapRows)
        ) yield rawLaps

    def laps(entry: Entry): Sql.Rows =
        Sql.rows(Sql.raw(Columns.table()))
            |> Sql.filter(Schema.scope(entry#season, entry#id))

}
