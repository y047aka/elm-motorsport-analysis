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

    /// A column as the schema declares it, which is all a `CREATE TABLE` needs
    /// and all a computed column has.
    pub type alias Declared = { name = String, sqlType = String }

    /// A column the database computes from the others: declared with the
    /// expression that makes it, read like any other, and bound by nothing.
    /// That last is why it is not a `Column` -- there is no row to bind it
    /// from, and so no way for it to reach a table's `all`, which is the
    /// ordering the insert follows.
    pub enum Computed[a] {
        case Computed({ name = String, sqlType = String, reading = String -> Sel[a] })
    }

    /// `VIRTUAL` rather than `STORED`: the expression is arithmetic over two
    /// columns of the same row, so the rows are no larger for having it.
    pub def computedInteger(name: String, expression: String): Computed[Int32] =
        Computed.Computed({
            name = name,
            sqlType = "int GENERATED ALWAYS AS (${expression}) VIRTUAL",
            reading = Sql.int
        })

    pub def declaredOf(computed: Computed[a]): Declared =
        let Computed.Computed(c) = computed;
        { name = c#name, sqlType = c#sqlType }

    pub def nameOf(computed: Computed[a]): String =
        let Computed.Computed(c) = computed;
        c#name

    pub def readOf(computed: Computed[a]): Sel[a] =
        let Computed.Computed(c) = computed;
        (c#reading)(c#name)

    pub def exprOf(computed: Computed[a]): Sql.Expr[a] =
        Sql.column(nameOf(computed))

    /// A computed column is one of the things a query may project.
    instance Sql.Project[Computed[a]] {
        type Out = a
        pub def sel(x: Computed[a]): Sel[a] = Db.Schema.readOf(x)
    }

    def declare(column: Bound[r]): Declared =
        { name = column#name, sqlType = column#sqlType }

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

    // ------------------------------------------------------------ the table

    pub def recreate(
        table: String,
        columns: List[Bound[r]],
        computed: List[Declared],
        keys: List[Sql.Key[Bound[r]]],
        storage: Sql.Storage
    ): Unit \ DbWrite =
        Db.execute(Sql.dropTableIfExists(table));
        Db.execute(createTable(table, columns, computed, keys, storage))

    /// The columns a row binds, then the ones the database makes: a computed
    /// column is declared like any other and is not in the ordering the insert
    /// follows, so this is the one place the two lists meet.
    pub def createTable(
        table: String,
        columns: List[Bound[r]],
        computed: List[Declared],
        keys: List[Sql.Key[Bound[r]]],
        storage: Sql.Storage
    ): String =
        Sql.createTable(
            table,
            List.append(columns |> List.map(declare), computed),
            keys |> List.map(Sql.mapKey(declare)),
            storage
        )

    pub def insertRows(table: String, columns: List[Bound[r]], rows: List[r]): Int32 \ DbWrite =
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
