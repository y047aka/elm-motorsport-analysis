/// The `laps` table -- its name, its columns, its keys, and the schema and
/// statements they make -- which is the whole of what this application tells
/// `Db` and `Sql` about itself.
///
/// A column's name, the type it takes in the table, how a row binds it and how
/// it reads back are one value. The schema the load creates, the values it
/// binds and the reading it comes back through are three views of that.
///
/// The type a column takes is the constructor's rather than a field of its
/// own: a `Bool` is stored as the 1 or 0 the driver binds it as, and a column
/// taking an `Option` is the nullable one.
mod Db.Laps {

    use Db.LapRow.LapRow
    use Db.Value
    use Sql.Sel

    pub enum Column[a] {
        case Column({ name = String, sqlType = String, bind = LapRow -> Value, read = Sel[a] })
    }

    /// A column with its reading forgotten. The twenty-eight do not share a
    /// type, so this is what an ordered list of them can hold.
    pub type alias Bound = { name = String, sqlType = String, bind = LapRow -> Value }

    pub def bound(column: Column[a]): Bound =
        let Column.Column(c) = column;
        { name = c#name, sqlType = c#sqlType, bind = c#bind }

    pub def name(column: Column[a]): String =
        let Column.Column(c) = column;
        c#name

    pub def read(column: Column[a]): Sel[a] =
        let Column.Column(c) = column;
        c#read

    /// A column is one of the things a query may project.
    instance Sql.Project[Column[a]] {
        type Out = a
        pub def sel(x: Column[a]): Sel[a] = Db.Laps.read(x)
    }

    /// The column as a term of a comparison, in the type it takes.
    pub def expr(column: Column[a]): Sql.Expr[a] =
        let Column.Column(c) = column;
        Sql.column(c#name)

    /// The column as a term a query groups or orders by, where its type says
    /// nothing.
    pub def term(column: Column[a]): Sql.Frag =
        Sql.term(expr(column))

    /// The table these columns are of.
    pub def table(): String = "laps"

    /// The table's rows, with its columns for a projection to pick from.
    pub def rows(): Sql.Rows[Columns] =
        rowsOf(Sql.raw(table()))

    /// As `rows`, where the source is the table read alongside something of
    /// its own -- `json_each` over one of its arrays, say. The columns are the
    /// table's either way.
    pub def rowsOf(source: Sql.Frag): Sql.Rows[Columns] =
        Sql.access(source, columns())

    /// One lap of one car of one round, which is what a row is at most one of.
    pub def primaryKey(): List[Bound] =
        let c = columns();
        bound(c#season) :: bound(c#round) :: bound(c#carNumber) :: bound(c#lapNumber) :: Nil

    /// The place the file listed a lap in, which a round has at most one lap
    /// at.
    pub def sourceKey(): List[Bound] =
        let c = columns();
        bound(c#season) :: bound(c#round) :: bound(c#sourceRow) :: Nil

    // ---------------------------------------------------------- the columns

    /// What a projection picks from, and what every other view of the table
    /// is built out of.
    pub type alias Columns = {
        season = Column[Int32],
        round = Column[String],
        sourceRow = Column[Int32],
        carNumber = Column[String],
        carClass = Column[String],
        carGroup = Column[String],
        team = Column[String],
        manufacturer = Column[String],
        driverNumber = Column[Int32],
        driverName = Column[String],
        lapNumber = Column[Int32],
        lapTimeMs = Column[Int32],
        lapImprovement = Column[Int32],
        crossingFinishLineInPit = Column[Bool],
        s1Ms = Column[Option[Int32]],
        s1Improvement = Column[Int32],
        s2Ms = Column[Option[Int32]],
        s2Improvement = Column[Int32],
        s3Ms = Column[Option[Int32]],
        s3Improvement = Column[Int32],
        kph = Column[String],
        elapsedMs = Column[Int32],
        hourMs = Column[Int32],
        topSpeed = Column[String],
        pitTimeMs = Column[Option[Int32]],
        flagAtFl = Column[String],
        miniSectorTimeMs = Column[Option[List[Option[Int32]]]],
        miniSectorElapsedMs = Column[Option[List[Option[Int32]]]]
    }

    /// The mini-sector pair is a JSON array of the fifteen of
    /// `Motorsport.MiniSector.all()` in track order, so a subscript is a place
    /// on the circuit; `json_each` is what a query reads one back with.
    pub def columns(): Columns = {
        season = integer("season", r -> r#season),
        round = text("round", r -> r#round),
        sourceRow = integer("source_row", r -> r#sourceRow),
        carNumber = text("car_number", r -> r#carNumber),
        carClass = text("class", r -> r#class),
        carGroup = text("car_group", r -> r#carGroup),
        team = text("team", r -> r#team),
        manufacturer = text("manufacturer", r -> r#manufacturer),
        driverNumber = integer("driver_number", r -> r#driverNumber),
        driverName = text("driver_name", r -> r#driverName),
        lapNumber = integer("lap_number", r -> r#lapNumber),
        lapTimeMs = integer("lap_time_ms", r -> r#lapTimeMs),
        lapImprovement = integer("lap_improvement", r -> r#lapImprovement),
        crossingFinishLineInPit = boolean("crossing_finish_line_in_pit", r -> r#crossingFinishLineInPit),
        s1Ms = nullableInteger("s1_ms", r -> r#s1Ms),
        s1Improvement = integer("s1_improvement", r -> r#s1Improvement),
        s2Ms = nullableInteger("s2_ms", r -> r#s2Ms),
        s2Improvement = integer("s2_improvement", r -> r#s2Improvement),
        s3Ms = nullableInteger("s3_ms", r -> r#s3Ms),
        s3Improvement = integer("s3_improvement", r -> r#s3Improvement),
        kph = text("kph", r -> r#kph),
        elapsedMs = integer("elapsed_ms", r -> r#elapsedMs),
        hourMs = integer("hour_ms", r -> r#hourMs),
        topSpeed = text("top_speed", r -> r#topSpeed),
        pitTimeMs = nullableInteger("pit_time_ms", r -> r#pitTimeMs),
        flagAtFl = text("flag_at_fl", r -> r#flagAtFl),
        miniSectorTimeMs = nullableIntArray("mini_sector_time_ms", r -> r#miniSectorTimeMs),
        miniSectorElapsedMs = nullableIntArray("mini_sector_elapsed_ms", r -> r#miniSectorElapsedMs)
    }

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    ///
    /// This and `Db.LapRow.selection` are two orderings of the same columns,
    /// and no compiler sees them together.
    pub def all(): List[Bound] =
        let c = columns();
        bound(c#season) ::
        bound(c#round) ::
        bound(c#sourceRow) ::
        bound(c#carNumber) ::
        bound(c#carClass) ::
        bound(c#carGroup) ::
        bound(c#team) ::
        bound(c#manufacturer) ::
        bound(c#driverNumber) ::
        bound(c#driverName) ::
        bound(c#lapNumber) ::
        bound(c#lapTimeMs) ::
        bound(c#lapImprovement) ::
        bound(c#crossingFinishLineInPit) ::
        bound(c#s1Ms) ::
        bound(c#s1Improvement) ::
        bound(c#s2Ms) ::
        bound(c#s2Improvement) ::
        bound(c#s3Ms) ::
        bound(c#s3Improvement) ::
        bound(c#kph) ::
        bound(c#elapsedMs) ::
        bound(c#hourMs) ::
        bound(c#topSpeed) ::
        bound(c#pitTimeMs) ::
        bound(c#flagAtFl) ::
        bound(c#miniSectorTimeMs) ::
        bound(c#miniSectorElapsedMs) ::
        Nil

    // --------------------------------------------------------------- schema

    /// Belongs before the first round: a schema this database will not take
    /// would otherwise be reported once per round, in the same words.
    pub def create(): Result[String, Unit] \ Db =
        forM(
            _ <- Db.execute(dropTable());
            _ <- Db.execute(createTable())
        ) yield ()

    pub def insertRows(rows: List[LapRow]): Result[String, Int32] \ Db =
        Db.insertMany(insert(), rows |> List.map(values))

    /// In the order `all` names them.
    pub def values(row: LapRow): List[Value] =
        all() |> List.map(c -> (c#bind)(row))

    /// The rows of one round: every reading of the table is of a single round,
    /// and the pair is what names one.
    pub def scope(inSeason: Int32, named: String): Sql.Expr[Bool] =
        let c = columns();
        Sql.every(
            Sql.eq(expr(c#season), Sql.i32(inSeason)) ::
            Sql.eq(expr(c#round), Sql.str(named)) :: Nil
        )

    /// `(hour - elapsed) mod 24h`, which the feed holds constant across a file
    /// and which is therefore where the round's start time is written.
    pub def hourOffset(): String =
        "((hour_ms - elapsed_ms) % 86400000 + 86400000) % 86400000"

    pub def dropTable(): String =
        "DROP TABLE IF EXISTS " + table()

    pub def createTable(): String =
        "CREATE TABLE " + table() + " (\n"
            + (definitions() |> List.map(d -> "  ${d}") |> List.join(",\n"))
            + ",\n  PRIMARY KEY (" + named(primaryKey()) + ")"
            + ",\n  UNIQUE (" + named(sourceKey()) + ")\n)"

    pub def insert(): String =
        "INSERT INTO " + table() + " (" + List.join(", ", columnNames()) + ") VALUES ("
            + List.join(", ", List.map(_ -> "?", columnNames())) + ")"

    def named(key: List[Bound]): String =
        key |> List.map(c -> c#name) |> List.join(", ")

    pub def columnNames(): List[String] =
        all() |> List.map(c -> c#name)

    def definitions(): List[String] =
        all() |> List.map(c -> "${c#name} ${c#sqlType}")

    // -------------------------------------------------------- constructors

    def column(name: String, sqlType: String, bind: LapRow -> Value, read: Sel[a]): Column[a] =
        Column.Column({ name = name, sqlType = sqlType, bind = bind, read = read })

    def integer(name: String, get: LapRow -> Int32): Column[Int32] =
        column(name, "int not null", r -> Value.Integer(get(r)), Sql.int(name))

    def text(name: String, get: LapRow -> String): Column[String] =
        column(name, "text not null", r -> Value.Text(get(r)), Sql.text(name))

    def boolean(name: String, get: LapRow -> Bool): Column[Bool] =
        column(name, "int not null", r -> Value.Boolean(get(r)), Sql.bool(name))

    def nullableInteger(name: String, get: LapRow -> Option[Int32]): Column[Option[Int32]] =
        column(name, "int", r -> Value.NullableInteger(get(r)), Sql.optionalInt(name))

    def nullableIntArray(name: String, get: LapRow -> Option[List[Option[Int32]]]): Column[Option[List[Option[Int32]]]] =
        column(name, "text", r -> Value.NullableIntArray(get(r)), Sql.optionalIntArray(name))

}
