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

    /// One lap of one car of one round, which is what a row is at most one of.
    pub def primaryKey(): List[Bound] =
        bound(season()) :: bound(round()) :: bound(carNumber()) :: bound(lapNumber()) :: Nil

    /// The place the file listed a lap in, which a round has at most one lap
    /// at.
    pub def sourceKey(): List[Bound] =
        bound(season()) :: bound(round()) :: bound(sourceRow()) :: Nil

    // ---------------------------------------------------------- the columns

    pub def season(): Column[Int32] = integer("season", r -> r#season)
    pub def round(): Column[String] = text("round", r -> r#round)
    pub def sourceRow(): Column[Int32] = integer("source_row", r -> r#sourceRow)
    pub def carNumber(): Column[String] = text("car_number", r -> r#carNumber)
    pub def carClass(): Column[String] = text("class", r -> r#class)
    pub def carGroup(): Column[String] = text("car_group", r -> r#carGroup)
    pub def team(): Column[String] = text("team", r -> r#team)
    pub def manufacturer(): Column[String] = text("manufacturer", r -> r#manufacturer)
    pub def driverNumber(): Column[Int32] = integer("driver_number", r -> r#driverNumber)
    pub def driverName(): Column[String] = text("driver_name", r -> r#driverName)
    pub def lapNumber(): Column[Int32] = integer("lap_number", r -> r#lapNumber)
    pub def lapTimeMs(): Column[Int32] = integer("lap_time_ms", r -> r#lapTimeMs)
    pub def lapImprovement(): Column[Int32] = integer("lap_improvement", r -> r#lapImprovement)
    pub def crossingFinishLineInPit(): Column[Bool] = boolean("crossing_finish_line_in_pit", r -> r#crossingFinishLineInPit)
    pub def s1Ms(): Column[Option[Int32]] = nullableInteger("s1_ms", r -> r#s1Ms)
    pub def s1Improvement(): Column[Int32] = integer("s1_improvement", r -> r#s1Improvement)
    pub def s2Ms(): Column[Option[Int32]] = nullableInteger("s2_ms", r -> r#s2Ms)
    pub def s2Improvement(): Column[Int32] = integer("s2_improvement", r -> r#s2Improvement)
    pub def s3Ms(): Column[Option[Int32]] = nullableInteger("s3_ms", r -> r#s3Ms)
    pub def s3Improvement(): Column[Int32] = integer("s3_improvement", r -> r#s3Improvement)
    pub def kph(): Column[String] = text("kph", r -> r#kph)
    pub def elapsedMs(): Column[Int32] = integer("elapsed_ms", r -> r#elapsedMs)
    pub def hourMs(): Column[Int32] = integer("hour_ms", r -> r#hourMs)
    pub def topSpeed(): Column[String] = text("top_speed", r -> r#topSpeed)
    pub def pitTimeMs(): Column[Option[Int32]] = nullableInteger("pit_time_ms", r -> r#pitTimeMs)
    pub def flagAtFl(): Column[String] = text("flag_at_fl", r -> r#flagAtFl)

    /// A JSON array of the fifteen of `Motorsport.MiniSector.all()` in track
    /// order, so a subscript is a place on the circuit. `json_each` is what a
    /// query reads one back with.
    pub def miniSectorTimeMs(): Column[Option[List[Option[Int32]]]] =
        nullableIntArray("mini_sector_time_ms", r -> r#miniSectorTimeMs)

    pub def miniSectorElapsedMs(): Column[Option[List[Option[Int32]]]] =
        nullableIntArray("mini_sector_elapsed_ms", r -> r#miniSectorElapsedMs)

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    ///
    /// This and `Db.LapRow.selection` are two orderings of the same columns,
    /// and no compiler sees them together.
    pub def all(): List[Bound] =
        bound(season()) ::
        bound(round()) ::
        bound(sourceRow()) ::
        bound(carNumber()) ::
        bound(carClass()) ::
        bound(carGroup()) ::
        bound(team()) ::
        bound(manufacturer()) ::
        bound(driverNumber()) ::
        bound(driverName()) ::
        bound(lapNumber()) ::
        bound(lapTimeMs()) ::
        bound(lapImprovement()) ::
        bound(crossingFinishLineInPit()) ::
        bound(s1Ms()) ::
        bound(s1Improvement()) ::
        bound(s2Ms()) ::
        bound(s2Improvement()) ::
        bound(s3Ms()) ::
        bound(s3Improvement()) ::
        bound(kph()) ::
        bound(elapsedMs()) ::
        bound(hourMs()) ::
        bound(topSpeed()) ::
        bound(pitTimeMs()) ::
        bound(flagAtFl()) ::
        bound(miniSectorTimeMs()) ::
        bound(miniSectorElapsedMs()) ::
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

    /// In the order `columns` names them.
    pub def values(row: LapRow): List[Value] =
        all() |> List.map(c -> (c#bind)(row))

    /// The rows of one round: every reading of the table is of a single round,
    /// and the pair is what names one.
    pub def scope(inSeason: Int32, named: String): Sql.Expr[Bool] =
        Sql.every(
            Sql.eq(expr(season()), Sql.i32(inSeason)) ::
            Sql.eq(expr(round()), Sql.str(named)) :: Nil
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
        "INSERT INTO " + table() + " (" + List.join(", ", columns()) + ") VALUES ("
            + List.join(", ", List.map(_ -> "?", columns())) + ")"

    def named(key: List[Bound]): String =
        key |> List.map(c -> c#name) |> List.join(", ")

    pub def columns(): List[String] =
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
