/// The round's cars, read back out of the rows it was loaded into.
mod Round.Cars {

    use Db.Cars
    use Db.CarRow
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawCar
    use Round.Names

    /// Whether a run has loaded the round's cars, asked rather than read back.
    pub def loaded(entry: Entry): Bool \ DbRead =
        let found = Cars.rows(entry)
            |> Sql.limit(1)
            |> Sql.map(_ -> Sql.int("1"))
            |> Sql.selectAll;
        not List.isEmpty(found)

    /// Keyed by car number, which is the whole of what a lap carries of its
    /// car. The team and the manufacturer are looked up once per round rather
    /// than joined per row: neither table is a round's, and both are small.
    pub def read(entry: Entry, names: Names.Names): Map[String, RawCar] \ DbRead =
        Cars.rows(entry)
            |> Sql.map(_ -> Cars.selection())
            |> Sql.selectAll
            |> List.map(row -> (row#carNumber, named(names, row)))
            |> List.toMap

    pub def named(names: Names.Names, row: CarRow.CarRow): RawCar \ DbErr =
        CarRow.toRawCar(
            Names.nameOf(names#teams, "team", row#teamId),
            Names.nameOf(names#manufacturers, "manufacturer", row#manufacturerId),
            row
        )

}
