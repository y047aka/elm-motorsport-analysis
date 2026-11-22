/// A table declared as its columns, which is what `Db.Laps` and `Db.Cars`
/// each are one of: a column's name, the type it takes there, how a row binds
/// it and how it reads back are one value, and the schema a load creates, the
/// values it binds and the reading it comes back through are three views of
/// that.
///
/// The type a column takes is the constructor's rather than a field of its
/// own: a `Bool` is stored as the 1 or 0 the driver binds it as, and a column
/// taking an `Option` is the nullable one.
pub mod Db.Schema {
    use Sqlitefx.DbWrite
    use Sqlitefx.RawSql
    use Sqlitefx.SqlValue
    use Sqlitefx.SqlValue.NullType

    use Sql.Sel

    /// A column of the table whose row is `r`, reading back as `a`.
    ///
    /// The reading is of a name rather than of this column's, so a column
    /// read from another source is this one under that source's name.
    pub enum Column[r, a] {
        case Column({ name = String, sqlType = String, bind = r -> SqlValue, reading = String -> Sel[a] })
    }

    /// A column with its reading forgotten. A table's columns do not share a
    /// type, so this is what an ordered list of them can hold.
    pub type alias Bound[r] = { name = String, sqlType = String, bind = r -> SqlValue }

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

    /// A column a common table expression names: the name it gives, the type the
    /// expression it selects has, and how that name reads back.
    ///
    /// Nothing binds such a column -- a derived source answers with rows and no row
    /// writes it -- so the `bind` is the one field of it no query reaches.
    pub def derived(name: String, sqlType: String, reading: String -> Sel[a]): Column[r, a] =
        column(name, sqlType, _ -> SqlValue.Null, reading)

    /// A statement written out names a column by its name and nothing else, so this
    /// is what `${c#carNumber}` puts between the keywords: the name, while the value
    /// interpolated is still the column and its type.
    instance ToString[Column[r, a]] {
        pub def toString(column: Column[r, a]): String =
            name(column)
    }

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
    ): Unit \ DbWrite + RawSql =
        discard Sqlitefx.Sql.execute(Sql.dropTableIfExists(table), Nil);
        discard Sqlitefx.Sql.execute(createTable(table, columns, computed, keys, storage), Nil)

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

    /// A tree the table carries beside its key, named for the table and the
    /// columns it is over so that two of them cannot collide.
    pub def createIndex(table: String, over: List[Bound[r]]): String =
        Sql.createIndex(indexName(table, over), table, over |> List.map(declare))

    pub def addIndex(table: String, over: List[Bound[r]]): Unit \ DbWrite + RawSql =
        discard Sqlitefx.Sql.execute(createIndex(table, over), Nil)

    def indexName(table: String, over: List[Bound[r]]): String =
        columnNames(over) |> List.foldLeft((acc, name) -> acc + "_" + name, table)

    /// The rows go out as one `INSERT` per thousand, each a statement SQLite takes or refuses whole, so a refusal leaves none of that statement's rows behind and the round's savepoint takes back the statements before it.
    ///
    /// A thousand rows is fewer where the table is wide: a statement binds at most 32,766 values, SQLite's own limit.
    pub def insertRows(table: String, columns: List[Bound[r]], rows: List[r]): Int32 \ DbWrite + RawSql =
        let perStatement = Int32.max(1, Int32.min(1000, 32766 / Int32.max(1, List.length(columns))));
        chunks(perStatement, rows) |> List.foldLeft((taken, chunk) -> match Sql.insertRows(table, columns, chunk) {
            case None => taken
            case Some((statement, bound_)) => taken + Sqlitefx.Sql.execute(statement, bound_)
        }, 0)

    def chunks(size: Int32, rows: List[r]): List[List[r]] = match rows {
        case Nil => Nil
        case _   => List.take(size, rows) :: chunks(size, List.drop(size, rows))
    }

    /// In the order the columns are named, which is the order the insert binds
    /// them.
    pub def values(columns: List[Bound[r]], row: r): List[SqlValue] =
        columns |> List.map(c -> (c#bind)(row))

    // ------------------------------------------------------- constructors

    def column(name: String, sqlType: String, bind: r -> SqlValue, reading: String -> Sel[a]): Column[r, a] =
        Column.Column({ name = name, sqlType = sqlType, bind = bind, reading = reading })

    pub def integer(name: String, get: r -> Int32): Column[r, Int32] =
        column(name, "int not null", row -> SqlValue.Int32(get(row)), Sql.int)

    /// The table's own integer primary key. Declared `integer` rather than
    /// `int` because SQLite makes such a column an alias for the row's own id
    /// only where the type is spelled exactly that -- and where it does, the
    /// rows are that key's tree and no second one is built over them.
    pub def identity(name: String, get: r -> Int32): Column[r, Int32] =
        column(name, "integer not null", row -> SqlValue.Int32(get(row)), Sql.int)

    pub def text(name: String, get: r -> String): Column[r, String] =
        column(name, "text not null", row -> SqlValue.Str(get(row)), Sql.text)

    /// The allowed values are written into the schema rather than bound, so
    /// they are the program's own: nothing a file said can reach here.
    pub def checkedText(name: String, allowed: List[String], get: r -> String): Column[r, String] =
        let inSet = allowed |> List.map(value -> "'${value}'") |> List.join(", ");
        column(name, "text not null check (${name} in (${inSet}))", row -> SqlValue.Str(get(row)), Sql.text)

    pub def boolean(name: String, get: r -> Bool): Column[r, Bool] =
        column(name, "int not null", row -> SqlValue.Bool(get(row)), Sql.bool)

    pub def nullableText(name: String, get: r -> Option[String]): Column[r, Option[String]] =
        column(name, "text",
            row -> SqlValue.ofOption(NullType.Str, SqlValue.Str, get(row)), Sql.optionalText)

    pub def nullableInteger(name: String, get: r -> Option[Int32]): Column[r, Option[Int32]] =
        column(name, "int",
            row -> SqlValue.ofOption(NullType.Int32, SqlValue.Int32, get(row)), Sql.optionalInt)

    pub def nullableIntArray(name: String, get: r -> Option[List[Option[Int32]]]): Column[r, Option[List[Option[Int32]]]] =
        column(name, "text",
            row -> SqlValue.ofOption(NullType.Json, values -> SqlValue.Json(jsonArray(values)), get(row)), Sql.optionalIntArray)

    /// The text a nullable-int-array column holds, which `json_each` reads back
    /// as one row per element.
    pub def jsonArray(values: List[Option[Int32]]): String =
        "[" + (values |> List.map(v -> match v {
            case Some(n) => "${n}"
            case None    => "null"
        }) |> List.join(",")) + "]"

}
