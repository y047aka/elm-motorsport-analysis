/// The round's laps, read back out of the rows it was loaded into.
mod Round.Laps {

    use Db.LapRow
    use Db.Schema
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawLap

    pub def read(entry: Entry): Result[String, List[RawLap]] \ Db =
        forM(
            rows    <- Db.fetch(Schema.selectRound(entry#season, entry#id));
            lapRows <- Result.traverse(LapRow.fromRow, rows);
            rawLaps <- Result.traverse(LapRow.toRawLap, lapRows)
        ) yield rawLaps

}
