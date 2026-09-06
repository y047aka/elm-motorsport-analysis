/// The `cars` table: the cars a round was run by, one row each. The class,
/// group, team and manufacturer the feed repeats on every lap are here rather
/// than in `Db.Laps`, which the archive bears out -- no `(season, round,
/// car_number)` in it is described two ways.
mod Db.Cars {

    use Db.CarRow.CarRow
    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Sql.Sel

    pub def table(): String = "cars"

    pub def rows(): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns())

    /// One car of one round, which is what a row is at most one of.
    pub def primaryKey(): List[Bound[CarRow]] =
        let c = columns();
        Schema.bound(c#season) :: Schema.bound(c#round) :: Schema.bound(c#carNumber) :: Nil

    // ---------------------------------------------------------- the columns

    pub type alias Columns = {
        season = Column[CarRow, Int32],
        round = Column[CarRow, String],
        carNumber = Column[CarRow, String],
        carClass = Column[CarRow, String],
        carGroup = Column[CarRow, String],
        team = Column[CarRow, String],
        manufacturer = Column[CarRow, String]
    }

    pub def columns(): Columns = {
        season = Schema.integer("season", r -> r#season),
        round = Schema.text("round", r -> r#round),
        carNumber = Schema.text("car_number", r -> r#carNumber),
        carClass = Schema.text("class", r -> r#class),
        carGroup = Schema.text("car_group", r -> r#carGroup),
        team = Schema.text("team", r -> r#team),
        manufacturer = Schema.text("manufacturer", r -> r#manufacturer)
    }

    /// A round's cars as the table holds them, a field at a time: each line
    /// names the column and the field its cell lands in, and a field left out
    /// is not a `CarRow`.
    pub def selection(): Sel[CarRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#season, (row, value) -> { +season = value | row })
            |> Sql.field(c#round, (row, value) -> { +round = value | row })
            |> Sql.field(c#carNumber, (row, value) -> { +carNumber = value | row })
            |> Sql.field(c#carClass, (row, value) -> { +class = value | row })
            |> Sql.field(c#carGroup, (row, value) -> { +carGroup = value | row })
            |> Sql.field(c#team, (row, value) -> { +team = value | row })
            |> Sql.field(c#manufacturer, (row, value) -> { +manufacturer = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    ///
    /// This and `Db.CarRow.selection` are two orderings of the same columns,
    /// and no compiler sees them together.
    pub def all(): List[Bound[CarRow]] =
        let c = columns();
        Schema.bound(c#season) ::
        Schema.bound(c#round) ::
        Schema.bound(c#carNumber) ::
        Schema.bound(c#carClass) ::
        Schema.bound(c#carGroup) ::
        Schema.bound(c#team) ::
        Schema.bound(c#manufacturer) ::
        Nil

    // --------------------------------------------------------------- schema

    pub def create(): Result[String, Unit] \ Db =
        Schema.recreate(table(), all(), keys())

    pub def insertRows(rows: List[CarRow]): Result[String, Int32] \ Db =
        Schema.insertRows(table(), all(), rows)

    pub def values(row: CarRow): List[Value] =
        Schema.values(all(), row)

    /// Taken of the columns a query was handed rather than of this table's
    /// own, so a reading of another source cannot be scoped by them.
    pub def scope(c: Columns, inSeason: Int32, named: String): Sql.Expr[Bool] =
        Schema.scopeOf(table(), c#season, c#round, inSeason, named)

    pub def createTable(): String =
        Sql.createTable(table(), all(), keys())

    def keys(): List[Sql.Key[Bound[CarRow]]] =
        Sql.Key.Primary(primaryKey()) :: Nil

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
