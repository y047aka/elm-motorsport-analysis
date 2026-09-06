/// A table declared as its columns, which is what `Db.Laps` and `Db.Cars`
/// each are one of: a column's name, the type it takes there, how a row binds
/// it and how it reads back are one value, and the schema a load creates, the
/// values it binds and the reading it comes back through are three views of
/// that.
///
/// The type a column takes is the constructor's rather than a field of its
/// own: a `Bool` is stored as the 1 or 0 the driver binds it as, and a column
/// taking an `Option` is the nullable one.
mod Db.Schema {

    use Db.Value
    use Sql.Sel

    /// A column of the table whose row is `r`, reading back as `a`.
    ///
    /// The reading is of a name rather than of this column's, so a column
    /// read from another source is this one under that source's name.
    pub enum Column[r, a] {
        case Column({ name = String, sqlType = String, bind = r -> Value, reading = String -> Sel[a] })
    }

    /// A column with its reading forgotten. A table's columns do not share a
    /// type, so this is what an ordered list of them can hold.
    pub type alias Bound[r] = { name = String, sqlType = String, bind = r -> Value }

    pub def bound(column: Column[r, a]): Bound[r] =
        let Column.Column(c) = column;
        { name = c#name, sqlType = c#sqlType, bind = c#bind }

    pub def name(column: Column[r, a]): String =
        let Column.Column(c) = column;
        c#name

    pub def read(column: Column[r, a]): Sel[a] =
        let Column.Column(c) = column;
        (c#reading)(c#name)

    /// The column as the named source has it, which is what a join names its
    /// sides' columns by. It reads and compares as `source.name`; what it
    /// binds is the table's, and no query asks that of it.
    pub def qualified(source: String, column: Column[r, a]): Column[r, a] =
        let Column.Column(c) = column;
        Column.Column({ name = source + "." + c#name | c })

    /// A column is one of the things a query may project.
    instance Sql.Project[Column[r, a]] {
        type Out = a
        pub def sel(x: Column[r, a]): Sel[a] = Db.Schema.read(x)
    }

    /// The column as a term of a comparison, in the type it takes.
    pub def expr(column: Column[r, a]): Sql.Expr[a] =
        let Column.Column(c) = column;
        Sql.column(c#name)

    /// The column as a term a query groups or orders by, where its type says
    /// nothing.
    pub def term(column: Column[r, a]): Sql.Frag =
        Sql.term(expr(column))

    pub def columnNames(these: List[Bound[r]]): List[String] =
        these |> List.map(c -> c#name)

    /// The rows of one round as the named source has them, which every
    /// reading of either table is scoped by.
    ///
    /// Both tables carry `season` and `round`, so a scope over bare column
    /// names binds to whichever side of a join happens to have them -- to the
    /// wrong side silently where only one does. Naming the source makes that
    /// a query the database refuses instead.
    pub def scopeOf(
        source: String,
        season: Column[r, Int32],
        round: Column[r, String],
        inSeason: Int32,
        named: String
    ): Sql.Expr[Bool] =
        Sql.every(
            Sql.eq(expr(qualified(source, season)), Sql.i32(inSeason)) ::
            Sql.eq(expr(qualified(source, round)), Sql.str(named)) :: Nil
        )

    // ------------------------------------------------------------ the table

    pub def recreate(table: String, columns: List[Bound[r]], keys: List[Sql.Key]): Result[String, Unit] \ Db =
        forM(
            _ <- Db.execute(Sql.dropTableIfExists(table));
            _ <- Db.execute(Sql.createTable(table, columns, keys))
        ) yield ()

    pub def insertRows(table: String, columns: List[Bound[r]], rows: List[r]): Result[String, Int32] \ Db =
        let (statement, bound_) = Sql.insertRows(table, columns, rows);
        Db.insertMany(statement, bound_)

    /// In the order the columns are named, which is the order the insert binds
    /// them.
    pub def values(columns: List[Bound[r]], row: r): List[Value] =
        columns |> List.map(c -> (c#bind)(row))

    // ------------------------------------------------------- constructors

    def column(name: String, sqlType: String, bind: r -> Value, reading: String -> Sel[a]): Column[r, a] =
        Column.Column({ name = name, sqlType = sqlType, bind = bind, reading = reading })

    pub def integer(name: String, get: r -> Int32): Column[r, Int32] =
        column(name, "int not null", row -> Value.Integer(get(row)), Sql.int)

    pub def text(name: String, get: r -> String): Column[r, String] =
        column(name, "text not null", row -> Value.Text(get(row)), Sql.text)

    pub def boolean(name: String, get: r -> Bool): Column[r, Bool] =
        column(name, "int not null", row -> Value.Boolean(get(row)), Sql.bool)

    pub def nullableInteger(name: String, get: r -> Option[Int32]): Column[r, Option[Int32]] =
        column(name, "int", row -> Value.NullableInteger(get(row)), Sql.optionalInt)

    pub def nullableIntArray(name: String, get: r -> Option[List[Option[Int32]]]): Column[r, Option[List[Option[Int32]]]] =
        column(name, "text", row -> Value.NullableIntArray(get(row)), Sql.optionalIntArray)

}
