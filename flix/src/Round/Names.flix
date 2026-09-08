/// The names a round's rows are read back through.
///
/// What `laps` and `cars` carry of a driver, a team and a manufacturer is an
/// id; this is what each of those was. Read once for the round rather than
/// once per reader: the seats are a join of two small tables, and neither
/// `teams` nor `manufacturers` is a round's at all -- a team is a team in
/// whichever round names it, and there are 72 of them against the 579 cars.
mod Round.Names {

    use Db.CarDrivers
    use Db.Drivers
    use Db.Manufacturers
    use Db.Rounds
    use Db.Schema
    use Db.Teams
    use Motorsport.Calendar.Entry

    pub type alias Names = {
        seats = Map[(String, Int32), String],
        teams = Map[Int32, String],
        manufacturers = Map[Int32, String]
    }

    pub def read(entry: Entry): Names \ DbRead =
        {
            seats = seats(entry),
            teams = Teams.rows()
                |> Sql.map(c -> (c#teamId, c#name))
                |> Sql.selectAll
                |> List.toMap,
            manufacturers = Manufacturers.rows()
                |> Sql.map(c -> (c#manufacturerId, c#name))
                |> Sql.selectAll
                |> List.toMap
        }

    /// Who sat where, keyed by the seat a lap names: `laps` carries the car's
    /// number and the seat, and the name is `car_drivers`'.
    def seats(entry: Entry): Map[(String, Int32), String] \ DbRead =
        let seat = CarDrivers.columns();
        let driver = Drivers.columns();
        Sql.access(
                Sql.frags(
                    Sql.raw("${CarDrivers.table()} JOIN ${Drivers.table()} ON") ::
                    Sql.term(Sql.eq(
                        Schema.expr(Schema.qualified(Drivers.table(), driver#driverId)),
                        Schema.expr(Schema.qualified(CarDrivers.table(), seat#driverId))
                    )) :: Nil
                ),
                {
                    carNumber = Schema.qualified(CarDrivers.table(), seat#carNumber),
                    driverNumber = Schema.qualified(CarDrivers.table(), seat#driverNumber),
                    roundId = Schema.qualified(CarDrivers.table(), seat#roundId),
                    name = Schema.qualified(Drivers.table(), driver#name)
                }
            )
            |> Sql.filter(c -> Rounds.scope(c#roundId, entry))
            |> Sql.map(c -> (c#carNumber, c#driverNumber, c#name))
            |> Sql.reading(match (carNumber, driverNumber, name) -> ((carNumber, driverNumber), name))
            |> Sql.selectAll
            |> List.toMap

    /// A lap naming a seat, or a car naming a team or a manufacturer, that no
    /// row answers to is a round loaded by halves -- which is the one thing
    /// the row cannot say for itself. Neither `teams` nor `manufacturers` is a
    /// round's, so neither is the miss.
    pub def driver(names: Names, carNumber: String, driverNumber: Int32): String \ DbErr =
        match Map.get((carNumber, driverNumber), names#seats) {
            case Some(name) => name
            case None       => DbErr.fail(Db.Error.Incomplete(
                "car ${carNumber} has laps from driver ${driverNumber}"
                    + " but is not one of the round's seats"))
        }

    pub def team(names: Names, id: Int32): String \ DbErr =
        found(names#teams, "team", id)

    pub def manufacturer(names: Names, id: Int32): String \ DbErr =
        found(names#manufacturers, "manufacturer", id)

    def found(names: Map[Int32, String], what: String, id: Int32): String \ DbErr =
        match Map.get(id, names) {
            case Some(name) => name
            case None       => DbErr.fail(Db.Error.Incomplete(
                "a car names ${what} ${id}, which no row in ${what}s answers to"))
        }

}
