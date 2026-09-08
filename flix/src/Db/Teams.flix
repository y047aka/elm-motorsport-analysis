/// The `teams` table: the teams the archive names, one row each. 72 of them
/// are named on the 579 cars, and 48 in more than one round.
mod Db.Teams {

    use Db.Numbering
    use Db.Numbering.Numbering
    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Sql.Sel

    pub def table(): String = "teams"

    pub type alias TeamRow = {
        teamId = Int32,
        name = String
    }

    pub def add(numbering: Numbering, names: List[String]): (Numbering, List[TeamRow]) =
        let (numbered, added) = Numbering.add(numbering, names);
        (numbered, added |> List.map(match (id, name) -> { teamId = id, name = name }))

    pub def idIn(numbering: Numbering, name: String): Option[Int32] =
        Numbering.idIn(numbering, name)

    pub def rows(): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns())

    pub def primaryKey(): List[Bound[TeamRow]] =
        Schema.bound(columns()#teamId) :: Nil

    pub def nameKey(): List[Bound[TeamRow]] =
        Schema.bound(columns()#name) :: Nil

    pub type alias Columns = {
        teamId = Column[TeamRow, Int32],
        name = Column[TeamRow, String]
    }

    pub def columns(): Columns = {
        teamId = Schema.identity("team_id", r -> r#teamId),
        name = Schema.text("name", r -> r#name)
    }

    pub def selection(): Sel[TeamRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#teamId, (row, value) -> { +teamId = value | row })
            |> Sql.field(c#name, (row, value) -> { +name = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them. This and `selection` are two orderings of the one declaration.
    pub def all(): List[Bound[TeamRow]] =
        let c = columns();
        Schema.bound(c#teamId) :: Schema.bound(c#name) :: Nil

    pub def create(): Unit \ DbWrite =
        Schema.recreate(table(), all(), Nil, keys(), storage())

    pub def insertRows(rows_: List[TeamRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows_)

    pub def values(row: TeamRow): List[Value] =
        Schema.values(all(), row)

    pub def createTable(): String =
        Schema.createTable(table(), all(), Nil, keys(), storage())

    def keys(): List[Sql.Key[Bound[TeamRow]]] =
        Sql.Key.Primary(primaryKey()) :: Sql.Key.Unique(nameKey()) :: Nil

    /// As `Db.Rounds`: `Schema.identity` makes the id the row's own.
    def storage(): Sql.Storage = Sql.Storage.Rowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
