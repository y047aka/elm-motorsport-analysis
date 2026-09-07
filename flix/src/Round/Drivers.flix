/// The round's seats, read back out of the rows it was loaded into.
mod Round.Drivers {

    use Db.CarDrivers
    use Db.Drivers
    use Db.Schema
    use Motorsport.Calendar.Entry

    /// Who sat where, keyed by the seat a lap names: `laps` carries the car's
    /// number and the seat, and the name is looked up once per round rather
    /// than read back once a lap.
    pub def read(entry: Entry): Map[(String, Int32), String] \ DbRead =
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
            |> Sql.filter(c -> Db.Rounds.scope(c#roundId, entry))
            |> Sql.map(c -> (c#carNumber, c#driverNumber, c#name))
            |> Sql.reading(match (carNumber, driverNumber, name) -> ((carNumber, driverNumber), name))
            |> Sql.selectAll
            |> List.toMap

    /// A lap naming a seat the round has no row for is a round loaded by
    /// halves, and is the one thing a lap cannot say for itself.
    pub def nameOf(seats: Map[(String, Int32), String], carNumber: String, driverNumber: Int32): String \ DbErr =
        match Map.get((carNumber, driverNumber), seats) {
            case Some(name) => name
            case None       => DbErr.fail(Db.Error.Incomplete(
                "car ${carNumber} has laps from driver ${driverNumber}"
                    + " but is not one of the round's seats"))
        }

}
