mod Db.CarRow {

    use Db.Cars
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawCar
    use Motorsport.Wec.RawLap
    use Sql.Sel

    /// One car of one round, which is what the feed repeats on every lap that
    /// car ran: no round in the archive names a car twice, so the file's first
    /// mention of one is the whole of what it says about it.
    pub type alias CarRow = {
        season = Int32,
        round = String,
        carNumber = String,
        class = String,
        carGroup = String,
        team = String,
        manufacturer = String
    }

    /// The cars the round's laps name, in the order the file first mentioned
    /// each. A car the file later contradicts itself about keeps what it was
    /// first said to be, which is the same reading the starting grid is
    /// ordered by.
    pub def fromRawLaps(entry: Entry, rawLaps: List[RawLap]): List[CarRow] =
        let gathered = List.foldLeft((acc, rawLap) -> {
            let number = rawLap#car#carNumber;
            if (Set.memberOf(number, acc#seen))
                acc
            else
                {
                    seen = Set.insert(number, acc#seen),
                    rows = fromRawCar(entry, rawLap#car) :: acc#rows
                }
        }, { seen = (Set.empty(): Set[String]), rows = (Nil: List[CarRow]) }, rawLaps);
        List.reverse(gathered#rows)

    pub def fromRawCar(entry: Entry, car: RawCar): CarRow =
        {
            season = entry#season,
            round = entry#id,
            carNumber = car#carNumber,
            class = car#class,
            carGroup = car#group,
            team = car#team,
            manufacturer = car#manufacturer
        }

    pub def toRawCar(row: CarRow): RawCar =
        {
            carNumber    = row#carNumber,
            class        = row#class,
            group        = row#carGroup,
            team         = row#team,
            manufacturer = row#manufacturer
        }

    /// A round's cars as the table holds them, a field at a time: each line
    /// names the column and the field its cell lands in, and a field left out
    /// is not a `CarRow`.
    pub def selection(): Sel[CarRow] =
        let c = Cars.columns();
        Sql.record({})
            |> Sql.field(c#season, (row, value) -> { +season = value | row })
            |> Sql.field(c#round, (row, value) -> { +round = value | row })
            |> Sql.field(c#carNumber, (row, value) -> { +carNumber = value | row })
            |> Sql.field(c#carClass, (row, value) -> { +class = value | row })
            |> Sql.field(c#carGroup, (row, value) -> { +carGroup = value | row })
            |> Sql.field(c#team, (row, value) -> { +team = value | row })
            |> Sql.field(c#manufacturer, (row, value) -> { +manufacturer = value | row })

}
