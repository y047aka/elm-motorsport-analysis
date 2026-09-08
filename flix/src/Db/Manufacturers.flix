/// The `manufacturers` table: every spelling the feed gives a manufacturer,
/// one row each, and which of them are one manufacturer.
///
/// A row is a spelling rather than a manufacturer, so `cars` can carry what
/// the file said and a query can still ask which manufacturer that was:
/// `canonical_id` points at the spelling `Motorsport.Manufacturer` calls the
/// name, and at the row itself where it knows of no other.
mod Db.Manufacturers {

    use Db.Numbering
    use Db.Numbering.Numbering
    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Motorsport.Manufacturer
    use Sql.Sel

    pub def table(): String = "manufacturers"

    pub type alias ManufacturerRow = {
        manufacturerId = Int32,
        name = String,
        canonicalId = Int32
    }

    /// The spellings this round adds, and the names they are spellings of: a
    /// spelling is numbered after the name it answers to, so the row it points
    /// at is there whether the feed has written that name yet or not.
    pub def add(numbering: Numbering, spellings: List[String]): (Numbering, List[ManufacturerRow]) =
        let named = spellings |> List.flatMap(spelling ->
            Manufacturer.canonicalOf(spelling) :: spelling :: Nil);
        let (numbered, added) = Numbering.add(numbering, named);
        (numbered, added |> List.map(match (id, name) -> {
            manufacturerId = id,
            name = name,
            canonicalId = Numbering.idIn(numbered, Manufacturer.canonicalOf(name))
                |> Option.getWithDefault(id)
        }))

    pub def idIn(numbering: Numbering, spelling: String): Option[Int32] =
        Numbering.idIn(numbering, spelling)

    /// A spelling the run numbered but no round has written a car under. The
    /// canonical name of an alias is one of these until a file spells it that
    /// way, so a manufacturer is one row and not two half-rows.
    pub def rows(): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns())

    pub def primaryKey(): List[Bound[ManufacturerRow]] =
        Schema.bound(columns()#manufacturerId) :: Nil

    pub def nameKey(): List[Bound[ManufacturerRow]] =
        Schema.bound(columns()#name) :: Nil

    pub type alias Columns = {
        manufacturerId = Column[ManufacturerRow, Int32],
        name = Column[ManufacturerRow, String],
        canonicalId = Column[ManufacturerRow, Int32]
    }

    pub def columns(): Columns = {
        manufacturerId = Schema.identity("manufacturer_id", r -> r#manufacturerId),
        name = Schema.text("name", r -> r#name),
        canonicalId = Schema.integer("canonical_id", r -> r#canonicalId)
    }

    pub def selection(): Sel[ManufacturerRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#manufacturerId, (row, value) -> { +manufacturerId = value | row })
            |> Sql.field(c#name, (row, value) -> { +name = value | row })
            |> Sql.field(c#canonicalId, (row, value) -> { +canonicalId = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them. This and `selection` are two orderings of the one declaration.
    pub def all(): List[Bound[ManufacturerRow]] =
        let c = columns();
        Schema.bound(c#manufacturerId) ::
        Schema.bound(c#name) ::
        Schema.bound(c#canonicalId) ::
        Nil

    pub def create(): Unit \ DbWrite =
        Schema.recreate(table(), all(), Nil, keys(), storage())

    pub def insertRows(rows_: List[ManufacturerRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows_)

    pub def values(row: ManufacturerRow): List[Value] =
        Schema.values(all(), row)

    pub def createTable(): String =
        Schema.createTable(table(), all(), Nil, keys(), storage())

    def keys(): List[Sql.Key[Bound[ManufacturerRow]]] =
        Sql.Key.Primary(primaryKey()) :: Sql.Key.Unique(nameKey()) :: Nil

    /// As `Db.Rounds`: `Schema.identity` makes the id the row's own.
    def storage(): Sql.Storage = Sql.Storage.Rowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
