/// The round's laps, read back out of the rows it was loaded into.
mod Round.Laps {

    use Db.LapRow
    use Db.Schema
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawLap

    /// Whether a run has loaded the round, asked rather than read back: a
    /// summary needs the answer and not the laps.
    pub def loaded(entry: Entry): Result[String, Bool] \ Db =
        Sql.int("1")
            |> Sql.selectAll(Sql.frags(
                Sql.raw("FROM laps WHERE") :: scope(entry) :: Sql.raw("LIMIT 1") :: Nil
            ))
            |> Result.map(rows -> not List.isEmpty(rows))

    pub def read(entry: Entry): Result[String, List[RawLap]] \ Db =
        forM(
            lapRows <- LapRow.selection() |> Sql.selectAll(Sql.frags(
                Sql.raw("FROM laps WHERE") :: scope(entry) :: Sql.raw("ORDER BY source_row") :: Nil
            ));
            rawLaps <- Result.traverse(LapRow.toRawLap, lapRows)
        ) yield rawLaps

    def scope(entry: Entry): Sql.Frag =
        Schema.scope(entry#season, entry#id)

}
