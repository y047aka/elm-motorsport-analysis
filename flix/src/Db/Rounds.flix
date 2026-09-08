/// The `rounds` table: the rounds `Motorsport.Calendar` lists, one row each,
/// and the id the other two tables name a round by.
///
/// The calendar stays the run's worklist and the server's answer -- none of it
/// is in the feed, and a database that is down must not stop the app being
/// used -- so this table is that calendar written down rather than a second
/// one. What it adds is an id: `laps` and `cars` carried a season and a round
/// name on every row, and 130,017 of those are the same fourteen pairs.
mod Db.Rounds {

    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Motorsport.Calendar.Entry
    use Sql.Sel

    pub def table(): String = "rounds"

    /// One round of one season, which is what a row is at most one of. The id
    /// is the calendar's order and means nothing outside the database it was
    /// written into: the tables are rebuilt together, so a run is the only
    /// thing that decides it.
    pub type alias RoundRow = {
        roundId = Int32,
        season = Int32,
        roundKey = String,
        date = String
    }

    pub def rows(): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns())

    pub def primaryKey(): List[Bound[RoundRow]] =
        Schema.bound(columns()#roundId) :: Nil

    /// The pair the calendar names a round by, which is what every reader has
    /// and the id is looked up from.
    pub def namedKey(): List[Bound[RoundRow]] =
        let c = columns();
        Schema.bound(c#season) :: Schema.bound(c#roundKey) :: Nil

    // ---------------------------------------------------------- the columns

    pub type alias Columns = {
        roundId = Column[RoundRow, Int32],
        season = Column[RoundRow, Int32],
        roundKey = Column[RoundRow, String],
        date = Column[RoundRow, String]
    }

    pub def columns(): Columns = {
        roundId = Schema.identity("round_id", r -> r#roundId),
        season = Schema.integer("season", r -> r#season),
        roundKey = Schema.text("round_key", r -> r#roundKey),
        date = Schema.text("date", r -> r#date)
    }

    pub def selection(): Sel[RoundRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#roundId, (row, value) -> { +roundId = value | row })
            |> Sql.field(c#season, (row, value) -> { +season = value | row })
            |> Sql.field(c#roundKey, (row, value) -> { +roundKey = value | row })
            |> Sql.field(c#date, (row, value) -> { +date = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    ///
    /// This and `selection` are two orderings of the one declaration, and no
    /// compiler sees them together.
    pub def all(): List[Bound[RoundRow]] =
        let c = columns();
        Schema.bound(c#roundId) ::
        Schema.bound(c#season) ::
        Schema.bound(c#roundKey) ::
        Schema.bound(c#date) ::
        Nil

    // ------------------------------------------------------------- the scope

    /// Where a round's id is read from, written as a subquery rather than
    /// looked up: a query naming a round stays one statement, and a database
    /// whose `rounds` does not have this one scopes to no rows rather than to
    /// another round's. Nothing else here would notice a calendar the rows
    /// were not written under.
    pub def idOf(entry: Entry): Sql.Expr[Int32] =
        let c = columns();
        Sql.written(Sql.frag(
            "(SELECT ${Schema.name(c#roundId)} FROM ${table()} WHERE"
                + " ${Schema.name(c#season)} = ? AND ${Schema.name(c#roundKey)} = ?)",
            Value.Integer(entry#season) :: Value.Text(entry#id) :: Nil
        ))

    /// The rows of one round, as the given column has its id. A join's side
    /// names itself, so a query over one hands in the column under that name.
    pub def scope(roundId: Column[r, Int32], entry: Entry): Sql.Expr[Bool] =
        Sql.eq(Schema.expr(roundId), idOf(entry))

    // --------------------------------------------------------------- schema

    /// The rounds the other two tables may name, written before either is
    /// filled: what they carry of a round is this table's id.
    ///
    /// Which rounds those are is the caller's -- `Motorsport.Calendar`'s for a
    /// run, and one made-up round for a test -- since an id means nothing
    /// outside the database it was written into.
    pub def create(entries: List[Entry]): List[RoundRow] \ DbWrite =
        Schema.recreate(table(), all(), Nil, keys(), storage());
        let rows_ = rowsFor(entries);
        discard insertRows(rows_);
        rows_

    pub def insertRows(rows_: List[RoundRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows_)

    pub def values(row: RoundRow): List[Value] =
        Schema.values(all(), row)

    /// The entries in the order given, numbered from one.
    pub def rowsFor(entries: List[Entry]): List[RoundRow] =
        entries
            |> List.zipWithIndex
            |> List.map(pair -> match pair {
                case (index, entry) => {
                    roundId = index + 1,
                    season = entry#season,
                    roundKey = entry#id,
                    date = entry#date
                }
            })

    /// The id the written rows gave this entry. `None` is a round the run did
    /// not write a row for, which is the one thing a load cannot number.
    pub def idIn(rows_: List[RoundRow], entry: Entry): Option[Int32] =
        rows_
            |> List.find(r -> r#season == entry#season and r#roundKey == entry#id)
            |> Option.map(r -> r#roundId)

    pub def createTable(): String =
        Schema.createTable(table(), all(), Nil, keys(), storage())

    def keys(): List[Sql.Key[Bound[RoundRow]]] =
        Sql.Key.Primary(primaryKey()) :: Sql.Key.Unique(namedKey()) :: Nil

    /// `Schema.identity` makes `round_id` the row's own id, so the rows are
    /// already the key's tree and `WITHOUT ROWID` would only rename it.
    def storage(): Sql.Storage = Sql.Storage.Rowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
