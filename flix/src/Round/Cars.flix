/// The round's cars, read back out of the rows it was loaded into.
mod Round.Cars {

    use Db.Cars
    use Db.CarRow
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawCar

    /// Keyed by car number, which is the whole of what a lap carries of its
    /// car.
    pub def read(entry: Entry): Result[String, Map[String, RawCar]] \ Db =
        Cars.rows()
            |> Sql.filter(Cars.scope(entry#season, entry#id))
            |> Sql.map(_ -> CarRow.selection())
            |> Sql.selectAll
            |> Result.map(rows -> rows
                |> List.map(row -> (row#carNumber, CarRow.toRawCar(row)))
                |> List.toMap)

}
