/// The `laps` table -- its name, its columns, its keys, and the schema and
/// statements they make. A lap carries its car's number and nothing else about
/// it: `Db.Cars` holds the class, group, team and manufacturer, which no round
/// in the archive varies within a car.
mod Db.Laps {

    use Db.LapRow.LapRow
    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value

    /// The table these columns are of.
    pub def table(): String = "laps"

    /// The table's rows, with its columns for a projection to pick from.
    pub def rows(): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns())

    /// As `rows`, read alongside something of the table's own -- `json_each`
    /// over one of its arrays, say. The table is the source either way, so all
    /// of its columns are there; a source that is not the table takes
    /// `Sql.access` and says for itself which of them it has.
    pub def rowsBeside(companion: Sql.Frag): Sql.Rows[Columns] =
        Sql.access(Sql.frags(Sql.raw(table() + ",") :: companion :: Nil), columns())

    /// One lap of one car of one round, which is what a row is at most one of.
    pub def primaryKey(): List[Bound[LapRow]] =
        let c = columns();
        Schema.bound(c#season) :: Schema.bound(c#round) ::
        Schema.bound(c#carNumber) :: Schema.bound(c#lapNumber) :: Nil

    /// The place the file listed a lap in, which a round has at most one lap
    /// at.
    pub def sourceKey(): List[Bound[LapRow]] =
        let c = columns();
        Schema.bound(c#season) :: Schema.bound(c#round) :: Schema.bound(c#sourceRow) :: Nil

    // ---------------------------------------------------------- the columns

    /// What a projection picks from, and what every other view of the table
    /// is built out of.
    pub type alias Columns = {
        season = Column[LapRow, Int32],
        round = Column[LapRow, String],
        sourceRow = Column[LapRow, Int32],
        carNumber = Column[LapRow, String],
        driverNumber = Column[LapRow, Int32],
        driverName = Column[LapRow, String],
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
        season = Schema.integer("season", r -> r#season),
        round = Schema.text("round", r -> r#round),
        sourceRow = Schema.integer("source_row", r -> r#sourceRow),
        carNumber = Schema.text("car_number", r -> r#carNumber),
        driverNumber = Schema.integer("driver_number", r -> r#driverNumber),
        driverName = Schema.text("driver_name", r -> r#driverName),
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

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    ///
    /// This and `Db.LapRow.selection` are two orderings of the same columns,
    /// and no compiler sees them together.
    pub def all(): List[Bound[LapRow]] =
        let c = columns();
        Schema.bound(c#season) ::
        Schema.bound(c#round) ::
        Schema.bound(c#sourceRow) ::
        Schema.bound(c#carNumber) ::
        Schema.bound(c#driverNumber) ::
        Schema.bound(c#driverName) ::
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

    pub def create(): Result[String, Unit] \ Db =
        Schema.recreate(table(), all(), keys())

    pub def insertRows(rows: List[LapRow]): Result[String, Int32] \ Db =
        Schema.insertRows(table(), all(), rows)

    pub def values(row: LapRow): List[Value] =
        Schema.values(all(), row)

    /// The rows of one round: every reading of the table is of a single round,
    /// and the pair is what names one.
    /// Taken of the columns a query was handed rather than of this table's
    /// own, so a reading of another source cannot be scoped by them.
    pub def scope(c: Columns, inSeason: Int32, named: String): Sql.Expr[Bool] =
        Schema.scopeOf(table(), c#season, c#round, inSeason, named)

    /// `(hour - elapsed) mod 24h`, which the feed holds constant across a file
    /// and which is therefore where the round's start time is written.
    pub def hourOffset(): String =
        "((hour_ms - elapsed_ms) % 86400000 + 86400000) % 86400000"

    pub def createTable(): String =
        Sql.createTable(table(), all(), keys())

    def keys(): List[Sql.Key] =
        Sql.Key.Primary(Schema.columnNames(primaryKey())) ::
        Sql.Key.Unique(Schema.columnNames(sourceKey())) :: Nil

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
