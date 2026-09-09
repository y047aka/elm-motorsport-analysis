/// The `entries` table: the cars a season was contested by, one row each.
///
/// The class, group, team and manufacturer the feed repeats on every lap of
/// every round are here rather than in `Db.Cars`, which holds only which of
/// them ran which round. A car number is an entry within its season and a
/// different one across seasons -- number 12 was three teams' over the three
/// the archive holds -- so the season is half of what names one.
mod Db.Entries {

    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Motorsport.Wec.RawCar
    use Sql.Sel

    pub def table(): String = "entries"

    pub type alias EntryRow = {
        entryId = Int32,
        season = Int32,
        carNumber = String,
        class = String,
        carGroup = Option[String],
        team = String,
        manufacturer = String
    }

    /// The entries a run has numbered so far. A run walks the rounds one at a
    /// time and an entry contests several, so what numbers them is carried
    /// between rounds rather than read back between them, and an id means
    /// nothing outside the database a run put it in.
    pub type alias Numbering = Map[(Int32, String), EntryRow]

    pub def noneNumbered(): Numbering = Map.empty()

    /// The entries this round adds, numbered after the ones already there, in
    /// the order the round first mentions each. A car the season already has
    /// keeps what it was first described as, and the description this round
    /// gave it instead is the second half of the answer.
    pub def add(
        numbering: Numbering,
        season: Int32,
        cars: List[RawCar]
    ): (Numbering, List[EntryRow], List[Disagreement]) =
        List.foldLeft((acc, car) -> {
            let (known, added, differing) = acc;
            match Map.get((season, car#carNumber), known) {
                case Some(first) => (known, added, List.append(differing, differences(first, car)))
                case None =>
                    let row = rowOf(Map.size(known) + 1, season, car);
                    (Map.insert((season, car#carNumber), row, known), row :: added, differing)
            }
        }, (numbering, Nil, Nil), cars)
            |> match (known, added, differing) -> (known, List.reverse(added), differing)

    pub def idIn(numbering: Numbering, season: Int32, carNumber: String): Option[Int32] =
        Map.get((season, carNumber), numbering) |> Option.map(row -> row#entryId)

    /// One car a later round of the same season described differently from
    /// the round that first named it: which of the four differs, what the
    /// table keeps, and what the later round said.
    pub type alias Disagreement = {
        season = Int32,
        carNumber = String,
        field = String,
        kept = String,
        found = String
    }

    /// What the load would otherwise drop without trace, as
    /// `Db.CarRow.disagreements` is within one round: the first round to name
    /// an entry describes it, and every later round's description of it
    /// reaches no column.
    def differences(kept: EntryRow, found: RawCar): List[Disagreement] =
        let said = (field, was, now) ->
            if (was == now) Nil
            else { season = kept#season, carNumber = kept#carNumber,
                   field = field, kept = was, found = now } :: Nil;
        List.flatten(
            said("class", kept#class, found#class) ::
            said("group", kept#carGroup |> Option.getWithDefault(""), found#group) ::
            said("team", kept#team, found#team) ::
            said("manufacturer", kept#manufacturer, found#manufacturer) :: Nil
        )

    /// The feed spells a car with no sub-class as one whose group is empty,
    /// which is the same thing said two ways and only one of them a value.
    def rowOf(entryId: Int32, season: Int32, car: RawCar): EntryRow =
        {
            entryId = entryId,
            season = season,
            carNumber = car#carNumber,
            class = car#class,
            carGroup = if (car#group == "") None else Some(car#group),
            team = car#team,
            manufacturer = car#manufacturer
        }

    pub def toRawCar(row: EntryRow): RawCar =
        {
            carNumber    = row#carNumber,
            class        = row#class,
            group        = row#carGroup |> Option.getWithDefault(""),
            team         = row#team,
            manufacturer = row#manufacturer
        }

    pub def primaryKey(): List[Bound[EntryRow]] =
        Schema.bound(columns()#entryId) :: Nil

    /// A car number is an entry within its season, which is what the table
    /// holds at most one row of.
    pub def seasonKey(): List[Bound[EntryRow]] =
        let c = columns();
        Schema.bound(c#season) :: Schema.bound(c#carNumber) :: Nil

    // ---------------------------------------------------------- the columns

    pub type alias Columns = {
        entryId = Column[EntryRow, Int32],
        season = Column[EntryRow, Int32],
        carNumber = Column[EntryRow, String],
        carClass = Column[EntryRow, String],
        carGroup = Column[EntryRow, Option[String]],
        team = Column[EntryRow, String],
        manufacturer = Column[EntryRow, String]
    }

    pub def columns(): Columns = {
        entryId = Schema.identity("entry_id", r -> r#entryId),
        season = Schema.integer("season", r -> r#season),
        carNumber = Schema.text("car_number", r -> r#carNumber),
        carClass = Schema.text("class", r -> r#class),
        carGroup = Schema.nullableText("car_group", r -> r#carGroup),
        team = Schema.text("team", r -> r#team),
        manufacturer = Schema.text("manufacturer", r -> r#manufacturer)
    }

    /// An entry as the table holds it, a field at a time: each line names the
    /// column and the field its cell lands in, and a field left out is not an
    /// `EntryRow`.
    pub def selection(): Sel[EntryRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#entryId, (row, value) -> { +entryId = value | row })
            |> Sql.field(c#season, (row, value) -> { +season = value | row })
            |> Sql.field(c#carNumber, (row, value) -> { +carNumber = value | row })
            |> Sql.field(c#carClass, (row, value) -> { +class = value | row })
            |> Sql.field(c#carGroup, (row, value) -> { +carGroup = value | row })
            |> Sql.field(c#team, (row, value) -> { +team = value | row })
            |> Sql.field(c#manufacturer, (row, value) -> { +manufacturer = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    pub def all(): List[Bound[EntryRow]] =
        let c = columns();
        Schema.bound(c#entryId) ::
        Schema.bound(c#season) ::
        Schema.bound(c#carNumber) ::
        Schema.bound(c#carClass) ::
        Schema.bound(c#carGroup) ::
        Schema.bound(c#team) ::
        Schema.bound(c#manufacturer) ::
        Nil

    // --------------------------------------------------------------- schema

    pub def create(): Unit \ DbWrite =
        Schema.recreate(table(), all(), Nil, keys(), storage())

    pub def insertRows(rows_: List[EntryRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows_)

    pub def values(row: EntryRow): List[Value] =
        Schema.values(all(), row)

    pub def createTable(): String =
        Schema.createTable(table(), all(), Nil, keys(), storage())

    def keys(): List[Sql.Key[Bound[EntryRow]]] =
        Sql.Key.Primary(primaryKey()) :: Sql.Key.Unique(seasonKey()) :: Nil

    /// As `Db.Drivers`: `Schema.identity` makes the id the row's own.
    def storage(): Sql.Storage = Sql.Storage.Rowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
