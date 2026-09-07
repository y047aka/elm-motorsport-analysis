/// The `car_drivers` table: which driver sat in which car, one row per seat.
///
/// The feed repeats a driver's name on every lap that driver ran, and names
/// the seat beside it -- `DRIVER_NUMBER`, which is 1, 2 or 3 through the whole
/// archive. `(round_id, car_number, driver_number)` names a seat and the name
/// is the same on every lap of it, in all 1,674 seats the archive has, so the
/// name is here and the lap carries the seat alone.
mod Db.CarDrivers {

    use Db.Drivers
    use Db.Numbering.Numbering
    use Db.Rounds
    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawLap
    use Sql.Sel

    pub def table(): String = "car_drivers"

    pub type alias CarDriverRow = {
        roundId = Int32,
        carNumber = String,
        driverNumber = Int32,
        driverId = Int32
    }

    /// One seat of one car of one round, which is what a row is at most one of.
    pub def primaryKey(): List[Bound[CarDriverRow]] =
        let c = columns();
        Schema.bound(c#roundId) :: Schema.bound(c#carNumber) :: Schema.bound(c#driverNumber) :: Nil

    pub def rows(entry: Entry): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns())
            |> Sql.filter(c -> Rounds.scope(Schema.qualified(table(), c#roundId), entry))

    // -------------------------------------------------------- the feed's side

    /// A seat and the name the file first gave it, in the order the file first
    /// mentioned each.
    pub type alias Seat = {
        carNumber = String,
        driverNumber = Int32,
        name = String
    }

    pub def seats(rawLaps: List[RawLap]): List[Seat] =
        let gathered = List.foldLeft((acc, rawLap) -> {
            let seat = (rawLap#car#carNumber, rawLap#driver#number);
            if (Set.memberOf(seat, acc#seen))
                acc
            else
                {
                    seen = Set.insert(seat, acc#seen),
                    found = {
                        carNumber = rawLap#car#carNumber,
                        driverNumber = rawLap#driver#number,
                        name = rawLap#driver#name
                    } :: acc#found
                }
        }, { seen = (Set.empty(): Set[(String, Int32)]), found = (Nil: List[Seat]) }, rawLaps);
        List.reverse(gathered#found)

    /// One lap whose seat the file gave a different name from its first
    /// mention. As `Db.CarRow.disagreements`: the second name reaches no
    /// column, so it is said here or nowhere. One lap is reported per seat.
    pub type alias Disagreement = {
        carNumber = String,
        driverNumber = Int32,
        lapNumber = Int32,
        kept = String,
        found = String
    }

    pub def disagreements(rawLaps: List[RawLap]): List[Disagreement] =
        let kept = seats(rawLaps)
            |> List.map(seat -> ((seat#carNumber, seat#driverNumber), seat#name))
            |> List.toMap;
        let gathered = List.foldLeft((acc, rawLap) -> {
            let seat = (rawLap#car#carNumber, rawLap#driver#number);
            let differs = match Map.get(seat, kept) {
                case Some(name) => name != rawLap#driver#name
                case None       => false
            };
            if (Set.memberOf(seat, acc#reported) or not differs)
                acc
            else
                {
                    reported = Set.insert(seat, acc#reported),
                    found = {
                        carNumber = rawLap#car#carNumber,
                        driverNumber = rawLap#driver#number,
                        lapNumber = rawLap#lapNumber,
                        kept = Map.getWithDefault(seat, "", kept),
                        found = rawLap#driver#name
                    } :: acc#found
                }
        }, { reported = (Set.empty(): Set[(String, Int32)]), found = (Nil: List[Disagreement]) }, rawLaps);
        List.reverse(gathered#found)

    /// A seat whose name the run did not number is a load that wrote the two
    /// tables from different readings of the file.
    pub def fromSeats(roundId: Int32, numbering: Numbering, seats_: List[Seat]): Option[List[CarDriverRow]] =
        seats_ |> List.map(seat ->
            Drivers.idIn(numbering, seat#name) |> Option.map(driverId -> {
                roundId = roundId,
                carNumber = seat#carNumber,
                driverNumber = seat#driverNumber,
                driverId = driverId
            })
        ) |> List.sequence

    // ---------------------------------------------------------- the columns

    pub type alias Columns = {
        roundId = Column[CarDriverRow, Int32],
        carNumber = Column[CarDriverRow, String],
        driverNumber = Column[CarDriverRow, Int32],
        driverId = Column[CarDriverRow, Int32]
    }

    pub def columns(): Columns = {
        roundId = Schema.integer("round_id", r -> r#roundId),
        carNumber = Schema.text("car_number", r -> r#carNumber),
        driverNumber = Schema.integer("driver_number", r -> r#driverNumber),
        driverId = Schema.integer("driver_id", r -> r#driverId)
    }

    pub def selection(): Sel[CarDriverRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#roundId, (row, value) -> { +roundId = value | row })
            |> Sql.field(c#carNumber, (row, value) -> { +carNumber = value | row })
            |> Sql.field(c#driverNumber, (row, value) -> { +driverNumber = value | row })
            |> Sql.field(c#driverId, (row, value) -> { +driverId = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them. This and `selection` are two orderings of the one declaration.
    pub def all(): List[Bound[CarDriverRow]] =
        let c = columns();
        Schema.bound(c#roundId) ::
        Schema.bound(c#carNumber) ::
        Schema.bound(c#driverNumber) ::
        Schema.bound(c#driverId) ::
        Nil

    // --------------------------------------------------------------- schema

    pub def create(): Unit \ DbWrite =
        Schema.recreate(table(), all(), Nil, keys(), storage())

    pub def insertRows(rows_: List[CarDriverRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows_)

    pub def values(row: CarDriverRow): List[Value] =
        Schema.values(all(), row)

    pub def createTable(): String =
        Schema.createTable(table(), all(), Nil, keys(), storage())

    def keys(): List[Sql.Key[Bound[CarDriverRow]]] =
        Sql.Key.Primary(primaryKey()) :: Nil

    /// As `Db.Laps` and `Db.Cars`: nothing reaches a row but through its key.
    def storage(): Sql.Storage = Sql.Storage.WithoutRowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
