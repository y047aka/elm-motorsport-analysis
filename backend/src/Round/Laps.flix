/// The round's laps, read back out of the rows it was loaded into.
pub mod Round.Laps {
    use Sqlitefx.DbErr
    use Sqlitefx.DbError.DbErrorKind
    use Sqlitefx.DbRead
    use Sqlitefx.RawSql
    use Sqlitefx.TransientDbErr

    use Db.LapRow
    use Db.LapRow.LapRow
    use Db.Laps
    use Db.Schema
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawCar
    use Motorsport.Wec.RawLap
    use Round.Cars
    use Round.Drivers
    use Round.Drivers.Seats

    /// Whether a run has loaded the round, asked rather than read back: a
    /// summary needs the answer and not the laps.
    pub def loaded(entry: Entry): Bool \ DbRead + RawSql =
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

    pub def read(entry: Entry, seats: Seats): List[Placed] \ DbRead + RawSql =
        let cars = Cars.read(entry);
        Laps.rows(entry)
            |> Sql.orderBy(Schema.term(Laps.columns()#sourceRow) :: Nil)
            |> Sql.map(_ -> (Laps.selection(), place()))
            |> Sql.selectAll
            |> List.map(placed(cars, seats))

    /// The rows are already the round's, so the field needs no partition of its
    /// own. Ties on the clock are broken by the file's order, which no two rows
    /// share.
    ///
    /// `Round.Timeline` counts the same order again, within each class, to find
    /// who led each lap: a place on the lap rides beside it, and the lead is a
    /// change between laps, so neither reading is the other's to hand over.
    def fieldOrder(): Sql.Window =
        let c = Laps.columns();
        Sql.window(
            Schema.term(c#lapNumber) :: Nil,
            Schema.term(c#elapsedMs) :: Schema.term(c#sourceRow) :: Nil,
            None
        )

    /// The place in the field, counted from nought where `ROW_NUMBER` counts from
    /// one.
    def place(): Sql.Sel[Int32] =
        Sql.intOf(Sql.frags(Sql.fragment(Sql.rowNumber(fieldOrder())) :: Sql.raw("- 1") :: Nil))

    def placed(cars: Map[String, RawCar], seats: Seats): ((LapRow, Int32)) -> Placed \ {DbErr, TransientDbErr} =
        row -> match row {
            case (lap, position) => { lap = rawLap(cars, seats)(lap), position = position }
        }

    /// A car with laps and no row in `cars` is a round loaded by halves, which
    /// is the one thing a lap cannot say for itself.
    def rawLap(cars: Map[String, RawCar], seats: Seats): LapRow -> RawLap \ {DbErr, TransientDbErr} =
        row ->
            match Map.get(row#carNumber, cars) {
                case None      => DbErr.raise(DbErrorKind.Other(
                    "car ${row#carNumber} has laps but is not one of the round's cars"))
                case Some(car) =>
                    let driver = Drivers.nameOf(seats, row#carNumber, row#driverNumber);
                    LapRow.toRawLap(car, driver, row)
                        |> Result.mapErr(DbErrorKind.Other)
                        |> Sql.orRaise
            }

}
