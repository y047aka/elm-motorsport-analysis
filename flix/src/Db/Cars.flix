/// The `cars` table: the cars a round was run by, one row each. The class,
/// group, team and manufacturer the feed repeats on every lap are here rather
/// than in `Db.Laps`, which the archive bears out -- no car of a round in it
/// is described two ways. The team and the manufacturer are ids: 72 team names
/// and 18 manufacturer spellings are written on the 579 cars.
mod Db.Cars {

    use Db.CarRow.CarRow
    use Db.Rounds
    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Motorsport.Calendar.Entry
    use Sql.Sel

    pub def table(): String = "cars"

    /// The round's rows. As `Db.Laps.rows`, the pair naming the round is
    /// applied here rather than left to the caller.
    pub def rows(entry: Entry): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns())
            |> Sql.filter(c -> scope(c, entry))

    /// One car of one round, which is what a row is at most one of.
    pub def primaryKey(): List[Bound[CarRow]] =
        let c = columns();
        Schema.bound(c#roundId) :: Schema.bound(c#carNumber) :: Nil

    // ---------------------------------------------------------- the columns

    pub type alias Columns = {
        roundId = Column[CarRow, Int32],
        carNumber = Column[CarRow, String],
        carClass = Column[CarRow, String],
        carGroup = Column[CarRow, String],
        teamId = Column[CarRow, Int32],
        manufacturerId = Column[CarRow, Int32]
    }

    pub def columns(): Columns = {
        roundId = Schema.integer("round_id", r -> r#roundId),
        carNumber = Schema.text("car_number", r -> r#carNumber),
        carClass = Schema.text("class", r -> r#class),
        carGroup = Schema.text("car_group", r -> r#carGroup),
        teamId = Schema.integer("team_id", r -> r#teamId),
        manufacturerId = Schema.integer("manufacturer_id", r -> r#manufacturerId)
    }

    /// A round's cars as the table holds them, a field at a time: each line
    /// names the column and the field its cell lands in, and a field left out
    /// is not a `CarRow`.
    pub def selection(): Sel[CarRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#roundId, (row, value) -> { +roundId = value | row })
            |> Sql.field(c#carNumber, (row, value) -> { +carNumber = value | row })
            |> Sql.field(c#carClass, (row, value) -> { +class = value | row })
            |> Sql.field(c#carGroup, (row, value) -> { +carGroup = value | row })
            |> Sql.field(c#teamId, (row, value) -> { +teamId = value | row })
            |> Sql.field(c#manufacturerId, (row, value) -> { +manufacturerId = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    ///
    /// This and `Db.CarRow.selection` are two orderings of the same columns,
    /// and no compiler sees them together.
    pub def all(): List[Bound[CarRow]] =
        let c = columns();
        Schema.bound(c#roundId) ::
        Schema.bound(c#carNumber) ::
        Schema.bound(c#carClass) ::
        Schema.bound(c#carGroup) ::
        Schema.bound(c#teamId) ::
        Schema.bound(c#manufacturerId) ::
        Nil

    // --------------------------------------------------------------- schema

    pub def create(): Unit \ DbWrite =
        Schema.recreate(table(), all(), keys(), storage())

    pub def insertRows(rows: List[CarRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows)

    pub def values(row: CarRow): List[Value] =
        Schema.values(all(), row)

    /// Taken of the columns the query was handed rather than of this table's
    /// own, so a reading of another source cannot be scoped by them.
    def scope(c: Columns, entry: Entry): Sql.Expr[Bool] =
        Rounds.scope(Schema.qualified(table(), c#roundId), entry)

    pub def createTable(): String =
        Sql.createTable(table(), all(), keys(), storage())

    def keys(): List[Sql.Key[Bound[CarRow]]] =
        Sql.Key.Primary(primaryKey()) :: Nil

    /// As `Db.Laps`: the rows are the primary key's tree.
    def storage(): Sql.Storage = Sql.Storage.WithoutRowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
