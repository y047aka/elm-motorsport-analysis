/// The round's laps, read back out of the rows it was loaded into.
mod Round.Laps {

    use Db.LapRow
    use Db.Schema
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawLap

    /// Whether a run has loaded the round, asked rather than read back: a
    /// summary needs the answer and not the laps.
    pub def loaded(entry: Entry): Result[String, Bool] \ Db =
        Db.fetch(Schema.anyRow(entry#season, entry#id))
            |> Result.map(rows -> not List.isEmpty(rows))

    pub def read(entry: Entry): Result[String, List[RawLap]] \ Db =
        forM(
            rows    <- Db.fetch(Schema.selectRound(entry#season, entry#id));
            lapRows <- Result.traverse(LapRow.fromRow, rows);
            rawLaps <- Result.traverse(LapRow.toRawLap, lapRows)
        ) yield rawLaps

}
