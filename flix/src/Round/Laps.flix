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
    pub def loaded(entry: Entry): Bool \ DbRead =
        let found = laps(entry)
            |> Sql.limit(1)
            |> Sql.map(_ -> Sql.int("1"))
            |> Sql.selectAll;
        not List.isEmpty(found)

    pub def read(entry: Entry): List[RawLap] \ DbRead =
        let cars = Cars.read(entry);
        laps(entry)
            |> Sql.orderBy(Schema.term(Laps.columns()#sourceRow) :: Nil)
            |> Sql.map(_ -> Laps.selection())
            |> Sql.selectAll
            |> List.map(rawLap(cars))

    /// A car with laps and no row in `cars` is a round loaded by halves, which
    /// is the one thing a lap cannot say for itself.
    def rawLap(cars: Map[String, RawCar]): LapRow -> RawLap \ DbErr =
        row ->
            match Map.get(row#carNumber, cars) {
                case None      => DbErr.fail(Db.Error.Incomplete(
                    "car ${row#carNumber} has laps but is not one of the round's cars"))
                case Some(car) => LapRow.toRawLap(car, row)
                    |> Result.mapErr(Db.Error.Unread)
                    |> Db.orRaise
            }

    def laps(entry: Entry): Sql.Rows[Laps.Columns] =
        Laps.rows()
            |> Sql.filter(c -> Laps.scope(c, entry#season, entry#id))

}
