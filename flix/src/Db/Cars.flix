/// The `cars` table: the cars a round was run by, one row each, and which of
/// the season's entries each was. What the feed says about a car is
/// `Db.Entries`; this is the rounds it ran.
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
        entryId = Column[CarRow, Int32]
    }

    pub def columns(): Columns = {
        roundId = Schema.integer("round_id", r -> r#roundId),
        carNumber = Schema.text("car_number", r -> r#carNumber),
        entryId = Schema.integer("entry_id", r -> r#entryId)
    }

    /// A round's cars as the table holds them, a field at a time: each line
    /// names the column and the field its cell lands in, and a field left out
    /// is not a `CarRow`.
    pub def selection(): Sel[CarRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#roundId, (row, value) -> { +roundId = value | row })
            |> Sql.field(c#carNumber, (row, value) -> { +carNumber = value | row })
            |> Sql.field(c#entryId, (row, value) -> { +entryId = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    ///
    /// This and `Db.CarRow.selection` are two orderings of the same columns,
    /// and no compiler sees them together.
    pub def all(): List[Bound[CarRow]] =
        let c = columns();
        Schema.bound(c#roundId) ::
        Schema.bound(c#carNumber) ::
        Schema.bound(c#entryId) ::
        Nil

    // --------------------------------------------------------------- schema

    pub def create(): Unit \ DbWrite =
        Schema.recreate(table(), all(), Nil, keys(), storage())

    pub def insertRows(rows: List[CarRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows)

    pub def values(row: CarRow): List[Value] =
        Schema.values(all(), row)

    /// Taken of the columns the query was handed rather than of this table's
    /// own, so a reading of another source cannot be scoped by them.
    def scope(c: Columns, entry: Entry): Sql.Expr[Bool] =
        Rounds.scope(Schema.qualified(table(), c#roundId), entry)

    pub def createTable(): String =
        Schema.createTable(table(), all(), Nil, keys(), storage())

    def keys(): List[Sql.Key[Bound[CarRow]]] =
        Sql.Key.Primary(primaryKey()) :: Nil

    /// As `Db.Laps`: the rows are the primary key's tree.
    def storage(): Sql.Storage = Sql.Storage.WithoutRowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
