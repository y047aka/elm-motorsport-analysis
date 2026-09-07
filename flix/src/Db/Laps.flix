/// The `laps` table -- its name, its columns, its keys, and the schema and
/// statements they make. A lap carries its car's number and the seat that ran
/// it, and nothing else about either: `Db.Cars` holds the class, group, team
/// and manufacturer, and `Db.CarDrivers` the seat's driver, none of which a
/// round in the archive varies within a car.
mod Db.Laps {

    use Db.LapRow.LapRow
    use Db.Rounds
    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Motorsport.Calendar.Entry
    use Sql.Sel

    /// The table these columns are of.
    pub def table(): String = "laps"

    /// The round's rows, with its columns for a projection to pick from.
    ///
    /// The pair naming the round is applied here rather than left to the
    /// caller: every reading of this table is of one round, and rows of the
    /// table at large are not something this module hands out.
    pub def rows(entry: Entry): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns()) |> scoped(entry)

    /// As `rows`, read alongside something of the table's own -- `json_each`
    /// over one of its arrays, say. The table is the source either way, so all
    /// of its columns are there; a source that is not the table takes
    /// `Sql.access` and says for itself which of them it has.
    pub def rowsBeside(entry: Entry, companion: Sql.Frag): Sql.Rows[Columns] =
        Sql.access(Sql.frags(Sql.raw(table() + ",") :: companion :: Nil), columns())
            |> scoped(entry)

    /// One lap of one car of one round, which is what a row is at most one of.
    pub def primaryKey(): List[Bound[LapRow]] =
        let c = columns();
        Schema.bound(c#roundId) :: Schema.bound(c#carNumber) :: Schema.bound(c#lapNumber) :: Nil

    /// The place the file listed a lap in, which a round has at most one lap
    /// at.
    pub def sourceKey(): List[Bound[LapRow]] =
        let c = columns();
        Schema.bound(c#roundId) :: Schema.bound(c#sourceRow) :: Nil

    // ---------------------------------------------------------- the columns

    /// What a projection picks from, and what every other view of the table
    /// is built out of.
    pub type alias Columns = {
        roundId = Column[LapRow, Int32],
        sourceRow = Column[LapRow, Int32],
        carNumber = Column[LapRow, String],
        driverNumber = Column[LapRow, Int32],
        lapNumber = Column[LapRow, Int32],
        lapTimeMs = Column[LapRow, Int32],
        lapImprovement = Column[LapRow, Int32],
        crossingFinishLineInPit = Column[LapRow, Bool],
        s1Ms = Column[LapRow, Option[Int32]],
        s1Improvement = Column[LapRow, Int32],
        s2Ms = Column[LapRow, Option[Int32]],
        s2Improvement = Column[LapRow, Int32],
        s3Ms = Column[LapRow, Option[Int32]],
        s3Improvement = Column[LapRow, Int32],
        kph = Column[LapRow, String],
        elapsedMs = Column[LapRow, Int32],
        hourMs = Column[LapRow, Int32],
        topSpeed = Column[LapRow, String],
        pitTimeMs = Column[LapRow, Option[Int32]],
        flagAtFl = Column[LapRow, String],
        miniSectorTimeMs = Column[LapRow, Option[List[Option[Int32]]]],
        miniSectorElapsedMs = Column[LapRow, Option[List[Option[Int32]]]]
    }

    /// The mini-sector pair is a JSON array of the fifteen of
    /// `Motorsport.MiniSector.all()` in track order, so a subscript is a place
    /// on the circuit; `json_each` is what a query reads one back with.
    pub def columns(): Columns = {
        roundId = Schema.integer("round_id", r -> r#roundId),
        sourceRow = Schema.integer("source_row", r -> r#sourceRow),
        carNumber = Schema.text("car_number", r -> r#carNumber),
        driverNumber = Schema.integer("driver_number", r -> r#driverNumber),
        lapNumber = Schema.integer("lap_number", r -> r#lapNumber),
        lapTimeMs = Schema.integer("lap_time_ms", r -> r#lapTimeMs),
        lapImprovement = Schema.integer("lap_improvement", r -> r#lapImprovement),
        crossingFinishLineInPit = Schema.boolean("crossing_finish_line_in_pit", r -> r#crossingFinishLineInPit),
        s1Ms = Schema.nullableInteger("s1_ms", r -> r#s1Ms),
        s1Improvement = Schema.integer("s1_improvement", r -> r#s1Improvement),
        s2Ms = Schema.nullableInteger("s2_ms", r -> r#s2Ms),
        s2Improvement = Schema.integer("s2_improvement", r -> r#s2Improvement),
        s3Ms = Schema.nullableInteger("s3_ms", r -> r#s3Ms),
        s3Improvement = Schema.integer("s3_improvement", r -> r#s3Improvement),
        kph = Schema.text("kph", r -> r#kph),
        elapsedMs = Schema.integer("elapsed_ms", r -> r#elapsedMs),
        hourMs = Schema.integer("hour_ms", r -> r#hourMs),
        topSpeed = Schema.text("top_speed", r -> r#topSpeed),
        pitTimeMs = Schema.nullableInteger("pit_time_ms", r -> r#pitTimeMs),
        flagAtFl = Schema.text("flag_at_fl", r -> r#flagAtFl),
        miniSectorTimeMs = Schema.nullableIntArray("mini_sector_time_ms", r -> r#miniSectorTimeMs),
        miniSectorElapsedMs = Schema.nullableIntArray("mini_sector_elapsed_ms", r -> r#miniSectorElapsedMs)
    }

    /// A round's laps as the table holds them, a field at a time: each line
    /// names the column and the field its cell lands in, and a field left out
    /// is not a `LapRow`.
    pub def selection(): Sel[LapRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#roundId, (row, value) -> { +roundId = value | row })
            |> Sql.field(c#sourceRow, (row, value) -> { +sourceRow = value | row })
            |> Sql.field(c#carNumber, (row, value) -> { +carNumber = value | row })
            |> Sql.field(c#driverNumber, (row, value) -> { +driverNumber = value | row })
            |> Sql.field(c#lapNumber, (row, value) -> { +lapNumber = value | row })
            |> Sql.field(c#lapTimeMs, (row, value) -> { +lapTimeMs = value | row })
            |> Sql.field(c#lapImprovement, (row, value) -> { +lapImprovement = value | row })
            |> Sql.field(c#crossingFinishLineInPit, (row, value) -> { +crossingFinishLineInPit = value | row })
            |> Sql.field(c#s1Ms, (row, value) -> { +s1Ms = value | row })
            |> Sql.field(c#s1Improvement, (row, value) -> { +s1Improvement = value | row })
            |> Sql.field(c#s2Ms, (row, value) -> { +s2Ms = value | row })
            |> Sql.field(c#s2Improvement, (row, value) -> { +s2Improvement = value | row })
            |> Sql.field(c#s3Ms, (row, value) -> { +s3Ms = value | row })
            |> Sql.field(c#s3Improvement, (row, value) -> { +s3Improvement = value | row })
            |> Sql.field(c#kph, (row, value) -> { +kph = value | row })
            |> Sql.field(c#elapsedMs, (row, value) -> { +elapsedMs = value | row })
            |> Sql.field(c#hourMs, (row, value) -> { +hourMs = value | row })
            |> Sql.field(c#topSpeed, (row, value) -> { +topSpeed = value | row })
            |> Sql.field(c#pitTimeMs, (row, value) -> { +pitTimeMs = value | row })
            |> Sql.field(c#flagAtFl, (row, value) -> { +flagAtFl = value | row })
            |> Sql.field(c#miniSectorTimeMs, (row, value) -> { +miniSectorTimeMs = value | row })
            |> Sql.field(c#miniSectorElapsedMs, (row, value) -> { +miniSectorElapsedMs = value | row })

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    ///
    /// This and `Db.LapRow.selection` are two orderings of the same columns,
    /// and no compiler sees them together.
    pub def all(): List[Bound[LapRow]] =
        let c = columns();
        Schema.bound(c#roundId) ::
        Schema.bound(c#sourceRow) ::
        Schema.bound(c#carNumber) ::
        Schema.bound(c#driverNumber) ::
        Schema.bound(c#lapNumber) ::
        Schema.bound(c#lapTimeMs) ::
        Schema.bound(c#lapImprovement) ::
        Schema.bound(c#crossingFinishLineInPit) ::
        Schema.bound(c#s1Ms) ::
        Schema.bound(c#s1Improvement) ::
        Schema.bound(c#s2Ms) ::
        Schema.bound(c#s2Improvement) ::
        Schema.bound(c#s3Ms) ::
        Schema.bound(c#s3Improvement) ::
        Schema.bound(c#kph) ::
        Schema.bound(c#elapsedMs) ::
        Schema.bound(c#hourMs) ::
        Schema.bound(c#topSpeed) ::
        Schema.bound(c#pitTimeMs) ::
        Schema.bound(c#flagAtFl) ::
        Schema.bound(c#miniSectorTimeMs) ::
        Schema.bound(c#miniSectorElapsedMs) ::
        Nil

    // --------------------------------------------------------------- schema

    pub def create(): Unit \ DbWrite =
        Schema.recreate(table(), all(), computed(), keys(), storage())

    pub def insertRows(rows: List[LapRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows)

    pub def values(row: LapRow): List[Value] =
        Schema.values(all(), row)

    /// The round's rows as a predicate, for a query reading them from inside
    /// one of its own: a common table expression's source is text, so it
    /// declares no columns for `rows` to scope.
    pub def inRound(entry: Entry): Sql.Expr[Bool] =
        scope(columns(), entry)

    /// Taken of the columns the query was handed rather than of this table's
    /// own, so a reading of another source cannot be scoped by them. Named for
    /// the table, since a join's other side has a `round_id` too.
    def scope(c: Columns, entry: Entry): Sql.Expr[Bool] =
        Rounds.scope(Schema.qualified(table(), c#roundId), entry)

    def scoped(entry: Entry, rows: Sql.Rows[Columns]): Sql.Rows[Columns] =
        rows |> Sql.filter(c -> scope(c, entry))

    /// `(hour - elapsed) mod 24h`, which the feed holds constant across a file
    /// and which is therefore where the round's start time is written. The
    /// database makes it, so a query compares it as a column of the type it
    /// has rather than pasting the arithmetic in twice.
    pub def hourOffsetMs(): Schema.Computed[Int32] =
        Schema.computedInteger(
            "hour_offset_ms",
            "((${Schema.name(columns()#hourMs)} - ${Schema.name(columns()#elapsedMs)})"
                + " % 86400000 + 86400000) % 86400000"
        )

    /// What the database makes rather than what a row binds, and so what `all`
    /// does not have.
    pub def computed(): List[Schema.Declared] =
        Schema.declaredOf(hourOffsetMs()) :: Nil

    pub def createTable(): String =
        Schema.createTable(table(), all(), computed(), keys(), storage())

    def keys(): List[Sql.Key[Bound[LapRow]]] =
        Sql.Key.Primary(primaryKey()) :: Sql.Key.Unique(sourceKey()) :: Nil

    /// Nothing reaches a row of this table but through a key of it, so the
    /// rows are the primary key's tree rather than a second one under it.
    def storage(): Sql.Storage = Sql.Storage.WithoutRowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
