/// The `drivers` table: the drivers the archive names, one row each.
///
/// A name is the whole of what the feed gives of a driver, so it is the key as
/// well as the value. 308 of them are named on 130,017 laps.
mod Db.Drivers {

    use Db.Numbering
    use Db.Numbering.Numbering
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

    /// The names this round adds, numbered after the ones already there, in
    /// the order the round first mentions each.
    pub def add(numbering: Numbering, names: List[String]): (Numbering, List[DriverRow]) =
        let (numbered, added) = Numbering.add(numbering, names);
        (numbered, added |> List.map(match (id, name) -> { driverId = id, name = name }))

    pub def noneNumbered(): Numbering = Numbering.none()

    pub def idIn(numbering: Numbering, name: String): Option[Int32] =
        Numbering.idIn(numbering, name)

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
        driverId = Schema.integer("driver_id", r -> r#driverId),
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
        Schema.recreate(table(), all(), keys(), storage())

    pub def insertRows(rows_: List[DriverRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows_)

    pub def values(row: DriverRow): List[Value] =
        Schema.values(all(), row)

    pub def createTable(): String =
        Sql.createTable(table(), all(), keys(), storage())

    def keys(): List[Sql.Key[Bound[DriverRow]]] =
        Sql.Key.Primary(primaryKey()) :: Sql.Key.Unique(nameKey()) :: Nil

    /// As `Db.Rounds`: an integer primary key is SQLite's own tree already.
    def storage(): Sql.Storage = Sql.Storage.Rowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
