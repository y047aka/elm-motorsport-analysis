/// The `drivers` table: the drivers the archive names, one row each.
///
/// A name is the whole of what the feed gives of a driver, so it is the key as
/// well as the value. 308 of them are named on 130,017 laps.
mod Db.Drivers {

    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Sql.Sel

    pub def table(): String = "drivers"

    pub type alias DriverRow = {
        driverId = Int32,
        name = String
    }

    /// The names a run has numbered so far. A run walks the rounds one at a
    /// time and a driver turns up in several, so what numbers them is carried
    /// between rounds rather than read back between them, and an id means
    /// nothing outside the database a run put it in.
    pub type alias Numbering = Map[String, Int32]

    pub def noneNumbered(): Numbering = Map.empty()

    /// The names this round adds, numbered after the ones already there, in
    /// the order the round first mentions each.
    pub def add(numbering: Numbering, names: List[String]): (Numbering, List[DriverRow]) =
        List.foldLeft((acc, name) -> {
            let (known, added) = acc;
            if (Map.memberOf(name, known))
                acc
            else
                let row = { driverId = Map.size(known) + 1, name = name };
                (Map.insert(name, row#driverId, known), row :: added)
        }, (numbering, Nil), names)
            |> match (known, added) -> (known, List.reverse(added))

    pub def idIn(numbering: Numbering, name: String): Option[Int32] =
        Map.get(name, numbering)

    pub def rows(): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns())

    pub def primaryKey(): List[Bound[DriverRow]] =
        Schema.bound(columns()#driverId) :: Nil

    pub def nameKey(): List[Bound[DriverRow]] =
        Schema.bound(columns()#name) :: Nil

    // ---------------------------------------------------------- the columns

    pub type alias Columns = {
        driverId = Column[DriverRow, Int32],
        name = Column[DriverRow, String]
    }

    pub def columns(): Columns = {
        driverId = Schema.identity("driver_id", r -> r#driverId),
        name = Schema.text("name", r -> r#name)
    }

    pub def selection(): Sel[DriverRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#driverId, (row, value) -> { +driverId = value | row })
            |> Sql.field(c#name, (row, value) -> { +name = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them. This and `selection` are two orderings of the one declaration.
    pub def all(): List[Bound[DriverRow]] =
        let c = columns();
        Schema.bound(c#driverId) :: Schema.bound(c#name) :: Nil

    // --------------------------------------------------------------- schema

    pub def create(): Unit \ DbWrite =
        Schema.recreate(table(), all(), Nil, keys(), storage())

    pub def insertRows(rows_: List[DriverRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows_)

    pub def values(row: DriverRow): List[Value] =
        Schema.values(all(), row)

    pub def createTable(): String =
        Schema.createTable(table(), all(), Nil, keys(), storage())

    def keys(): List[Sql.Key[Bound[DriverRow]]] =
        Sql.Key.Primary(primaryKey()) :: Sql.Key.Unique(nameKey()) :: Nil

    /// As `Db.Rounds`: `Schema.identity` makes the id the row's own.
    def storage(): Sql.Storage = Sql.Storage.Rowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
