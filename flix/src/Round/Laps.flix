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
    use Round.Drivers

    /// Whether a run has loaded the round, asked rather than read back: a
    /// summary needs the answer and not the laps.
    pub def loaded(entry: Entry): Bool \ DbRead =
        let found = Laps.rows(entry)
            |> Sql.limit(1)
            |> Sql.map(_ -> Sql.int("1"))
            |> Sql.selectAll;
        not List.isEmpty(found)

    /// One lap on its way out, and where its car stood in the field as it
    /// crossed the line. The place is counted over the round's rows rather
    /// than held by any one of them, so it rides beside the lap: a `RawLap` is
    /// what the feed said, and the feed does not say this.
    pub type alias Placed = {
        lap = RawLap,
        position = Int32
    }

    pub def read(entry: Entry): List[Placed] \ DbRead =
        let cars = Cars.read(entry);
        let seats = Drivers.read(entry);
        Laps.rows(entry)
            |> Sql.orderBy(Schema.term(Laps.columns()#sourceRow) :: Nil)
            |> Sql.map(_ -> (Laps.selection(), Sql.int(placeInField())))
            |> Sql.selectAll
            |> List.map(placed(cars, seats))

    /// Counted from nought, which is what `Motorsport.Race.TimelineEvent`
    /// reads the lead off. A window runs over the rows the round was scoped
    /// to, so the field is this round's and not the table's. Ties on the clock
    /// are broken by the file's order, which no two rows share.
    def placeInField(): String =
        "ROW_NUMBER() OVER (PARTITION BY lap_number ORDER BY elapsed_ms, source_row) - 1"

    def placed(
        cars: Map[String, RawCar],
        seats: Map[(String, Int32), String]
    ): ((LapRow, Int32)) -> Placed \ DbErr =
        row -> match row {
            case (lap, position) => { lap = rawLap(cars, seats)(lap), position = position }
        }

    /// A car with laps and no row in `cars` is a round loaded by halves, which
    /// is the one thing a lap cannot say for itself.
    def rawLap(cars: Map[String, RawCar], seats: Map[(String, Int32), String]): LapRow -> RawLap \ DbErr =
        row ->
            match Map.get(row#carNumber, cars) {
                case None      => DbErr.fail(Db.Error.Incomplete(
                    "car ${row#carNumber} has laps but is not one of the round's cars"))
                case Some(car) =>
                    let driver = Drivers.nameOf(seats, row#carNumber, row#driverNumber);
                    LapRow.toRawLap(car, driver, row)
                        |> Result.mapErr(Db.Error.Unread)
                        |> Db.orRaise
            }

}
