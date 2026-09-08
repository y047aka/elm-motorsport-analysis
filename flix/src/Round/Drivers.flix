/// The round's seats, read back out of the rows it was loaded into.
///
/// `laps` carries the car's number and the seat that ran it, and this is who
/// that was. Read once for the round by whichever caller asked for it and
/// handed to the readers, rather than fetched again by each of them.
mod Round.Drivers {

    use Db.CarDrivers
    use Db.Drivers
    use Db.Rounds
    use Db.Schema
    use Motorsport.Calendar.Entry

    /// Keyed by the seat a lap names.
    pub type alias Seats = Map[(String, Int32), String]

    pub def read(entry: Entry): Seats \ DbRead =
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

    /// A lap naming a seat the round has no row for is a round loaded by
    /// halves, and is the one thing a lap cannot say for itself.
    pub def nameOf(seats: Seats, carNumber: String, driverNumber: Int32): String \ DbErr =
        match Map.get((carNumber, driverNumber), seats) {
            case Some(name) => name
            case None       => DbErr.fail(Db.Error.Incomplete(
                "car ${carNumber} has laps from driver ${driverNumber}"
                    + " but is not one of the round's seats"))
        }

}
