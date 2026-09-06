/// The round's laps, read back out of the rows it was loaded into.
mod Round.Laps {

    use Db.LapRow
    use Db.LapRow.LapRow
    use Db.Laps
    use Db.Schema
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawCar
    use Motorsport.Wec.RawLap
    use Round.Cars

    /// Whether a run has loaded the round, asked rather than read back: a
    /// summary needs the answer and not the laps.
    pub def loaded(entry: Entry): Result[String, Bool] \ Db =
        laps(entry)
            |> Sql.limit(1)
            |> Sql.map(_ -> Sql.int("1"))
            |> Sql.selectAll
            |> Result.map(found -> not List.isEmpty(found))

    pub def read(entry: Entry): Result[String, List[RawLap]] \ Db =
        forM(
            cars    <- Cars.read(entry);
            lapRows <- laps(entry)
                |> Sql.orderBy(Schema.term(Laps.columns()#sourceRow) :: Nil)
                |> Sql.map(_ -> LapRow.selection())
                |> Sql.selectAll;
            rawLaps <- Result.traverse(rawLap(cars), lapRows)
        ) yield rawLaps

    /// A car with laps and no row in `cars` is a round loaded by halves, which
    /// is the one thing a lap cannot say for itself.
    def rawLap(cars: Map[String, RawCar]): LapRow -> Result[String, RawLap] =
        row ->
            Map.get(row#carNumber, cars)
                |> Option.toOk("car ${row#carNumber} has laps but is not one of the round's cars")
                |> Result.flatMap(car -> LapRow.toRawLap(car, row))

    def laps(entry: Entry): Sql.Rows[Laps.Columns] =
        Laps.rows()
            |> Sql.filter(c -> Laps.scope(c, entry#season, entry#id))

}
