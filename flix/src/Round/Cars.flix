/// The round's cars, read back out of the rows it was loaded into.
mod Round.Cars {

    use Db.Cars
    use Db.CarRow
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawCar

    /// Whether a run has loaded the round's cars, asked rather than read back.
    pub def loaded(entry: Entry): Bool \ DbRead =
        let found = Cars.rows()
            |> Sql.filter(c -> Cars.scope(c, entry#season, entry#id))
            |> Sql.limit(1)
            |> Sql.map(_ -> Sql.int("1"))
            |> Sql.selectAll;
        not List.isEmpty(found)

    /// Keyed by car number, which is the whole of what a lap carries of its
    /// car.
    pub def read(entry: Entry): Map[String, RawCar] \ DbRead =
        Cars.rows()
            |> Sql.filter(c -> Cars.scope(c, entry#season, entry#id))
            |> Sql.map(_ -> Cars.selection())
            |> Sql.selectAll
            |> List.map(row -> (row#carNumber, CarRow.toRawCar(row)))
            |> List.toMap

}
