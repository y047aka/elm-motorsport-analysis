/// Building the SQL this repository sends, out of the pieces it is made of.
///
/// A `Frag` is a piece of a statement and the values its `?` placeholders bind.
/// An `Expr` is one of those with the type its SQL value has. A `Sel` is one
/// projection and the reading of the cells it comes back as held in the same
/// value, so a clause is rendered from the readings rather than written beside
/// them, and a column is named once.
///
/// What a query projects is a `Project` -- a reading, a tuple of them, or
/// whatever else is given an instance, as `Db.Laps` gives its columns one -- so
/// the clause and the value that comes back are the one expression read twice.
///
/// A row is read by the label each projected expression comes back under, which
/// the same expression writes into the clause; see `label`. Within the row put in
/// that order a reading stops at the first cell it cannot read, so past a failure
/// there is no longer a position to report the next problem at.
pub mod Sql {
    use Lite3fx.DbErr
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.DbRead
    use Lite3fx.Row
    use Lite3fx.Row.Row
    use Lite3fx.SqlValue

    ///
    /// ===== FRAGMENTS =====
    ///

    /// A piece of a query and the values its `?` placeholders bind, kept
    /// together so that concatenating two pieces cannot put a value under the
    /// wrong placeholder.
    pub enum Frag {
        case Frag(String, List[SqlValue])
    }

    /// A piece of a query binding nothing.
    pub def raw(sql: String): Frag =
        Frag.Frag(sql, Nil)

    /// A piece of a query whose `?` placeholders bind `params`, left to right.
    pub def frag(sql: String, params: List[SqlValue]): Frag =
        Frag.Frag(sql, params)

    /// The pieces in order, separated by a space where both sides have one.
    pub def frags(pieces: List[Frag]): Frag =
        joinFrags(" ", pieces)

    /// A piece contributing no text still contributes its values: only the
    /// text is dropped, so that a separator does not fall either side of it.
    def joinFrags(separator: String, pieces: List[Frag]): Frag =
        let sql = pieces
            |> List.map(piece -> { let Frag.Frag(text, _) = piece; text })
            |> List.filter(text -> not String.isEmpty(text))
            |> List.join(separator);
        let params = pieces |> List.flatMap(piece -> { let Frag.Frag(_, values) = piece; values });
        Frag.Frag(sql, params)

    pub def toSql(fragment: Frag): (String, List[SqlValue]) =
        let Frag.Frag(sql, params) = fragment;
        (sql, params)

    /// The text of a projection, which is what a statement written out interpolates: a
    /// column's name, an aggregate over declared columns, a window's clauses.
    ///
    /// A projection that binds values has nowhere else they could go, and its text says how many it binds rather than pretending they are not there.
    pub def sqlOf(p: p): String with Project[p] =
        sqlText(columnsOf(p))

    def sqlText(fragment: Frag): String =
        let Frag.Frag(sql, params) = fragment;
        if (List.isEmpty(params))
            sql
        else
            "${sql} /* binds ${List.length(params)} */"

    ///
    /// ===== EXPRESSIONS =====
    ///

    /// A typed expression. The type is the one the SQL value has, carried so
    /// that a comparison against a value of another type does not compile, and
    /// so that `IS NULL` can be asked only of a column that takes one. What is
    /// rendered is the fragment.
    pub enum Expr[_a] {
        case Expr(Frag)
    }

    /// An expression named rather than drawn from a column -- what a common
    /// table expression makes up, and what no combinator here builds. Its type
    /// is the caller's word.
    pub def column(name: String): Expr[a] =
        written(raw(name))

    /// An expression the caller wrote out, values and all -- a scalar subquery,
    /// say. As `column`, its type is the caller's word.
    pub def written(fragment: Frag): Expr[a] =
        Expr.Expr(fragment)

    pub def i32(value: Int32): Expr[Int32] =
        Expr.Expr(Frag.Frag("?", SqlValue.Int32(value) :: Nil))

    pub def str(value: String): Expr[String] =
        Expr.Expr(Frag.Frag("?", SqlValue.Str(value) :: Nil))

    pub def eq(left: Expr[a], right: Expr[a]): Expr[Bool] = binary("=", left, right)
    pub def ne(left: Expr[a], right: Expr[a]): Expr[Bool] = binary("<>", left, right)
    pub def lte(left: Expr[a], right: Expr[a]): Expr[Bool] = binary("<=", left, right)
    pub def isNotNull(expr: Expr[Option[a]]): Expr[Bool] = postfix("IS NOT NULL", expr)
    pub def isNull(expr: Expr[Option[a]]): Expr[Bool] = postfix("IS NULL", expr)

    /// The predicates, ANDed. Nothing asked is `1 = 1` rather than an empty
    /// fragment: this goes where a predicate is expected, and a caller ANDing
    /// its own onto it would otherwise be left with `AND` beside nothing.
    pub def every(predicates: List[Expr[Bool]]): Expr[Bool] =
        match predicates {
            case Nil => Expr.Expr(raw("1 = 1"))
            case _   => Expr.Expr(joinFrags(" AND ", predicates |> List.map(term)))
        }

    pub def term(expr: Expr[a]): Frag =
        let Expr.Expr(fragment) = expr;
        fragment

    def binary(operator: String, left: Expr[a], right: Expr[a]): Expr[Bool] =
        Expr.Expr(frags(term(left) :: raw(operator) :: term(right) :: Nil))

    def postfix(operator: String, expr: Expr[a]): Expr[Bool] =
        Expr.Expr(frags(term(expr) :: raw(operator) :: Nil))

    ///
    /// ===== READINGS =====
    ///

    /// The expressions of the SELECT clause, and a reading of the cells they
    /// come back as which answers with what is left of the row.
    pub enum Sel[a] {
        case Sel(List[Frag], Row -> Result[DbErrorKind, (a, Row)])
    }

    def cell(expr: Frag, read: String -> SqlValue -> Result[DbErrorKind, a]): Sel[a] =
        let Frag.Frag(text, _) = expr;
        Sel.Sel(expr :: Nil, row -> match Row.uncons(row) {
            case Some((_, value, rest)) => read(text, value) |> Result.map(read_ -> (read_, rest))
            case None                   => Err(DbErrorKind.Other("the row ended before `${text}`"))
        })

    /// A cell the reading wants as text. The schema binds text and SQLite keeps
    /// what it is given, so a column is asked for as text whatever the driver
    /// answered it in -- which is also how an expression's cell arrives.
    pub def text(expr: String): Sel[String] =
        cell(raw(expr), (name, v) -> nonNull(name, v) |> Result.map(SqlValue.textOf))

    pub def optionalText(expr: String): Sel[Option[String]] =
        cell(raw(expr), (_, v) ->
            if (SqlValue.isNull(v)) Ok(None) else Ok(Some(SqlValue.textOf(v))))

    pub def int(expr: String): Sel[Int32] =
        intOf(raw(expr))

    /// As `int`, where the expression is one a query built.
    ///
    /// A number the driver answered in another type -- a `SUM`, a `json_each`
    /// element -- is read from its text, which is the one form every cell has.
    pub def intOf(expr: Frag): Sel[Int32] =
        cell(expr, (name, v) ->
            if (SqlValue.isNull(v)) Err(DbErrorKind.DecodeError(name, "was null"))
            else match SqlValue.int32Of(v) {
                case Some(n) => Ok(n)
                case None    => parseInt(name, SqlValue.textOf(v))
            })

    /// A truth value is stored as the 1 or 0 the driver bound it as.
    pub def bool(expr: String): Sel[Bool] =
        cell(raw(expr), (name, v) -> match v {
            case SqlValue.Int32(1)  => Ok(true)
            case SqlValue.Int32(0)  => Ok(false)
            case SqlValue.Null      => Err(DbErrorKind.DecodeError(name, "was null"))
            case _ => match SqlValue.textOf(v) {
                case "1" => Ok(true)
                case "0" => Ok(false)
                case t   => Err(DbErrorKind.DecodeError(name, "is not a boolean: \"${t}\""))
            }
        })

    pub def optionalInt(expr: String): Sel[Option[Int32]] =
        optionalIntOf(raw(expr))

    /// As `optionalInt`, where the expression binds values of its own.
    pub def optionalIntOf(expr: Frag): Sel[Option[Int32]] =
        cell(expr, (name, v) ->
            if (SqlValue.isNull(v)) Ok(None)
            else match SqlValue.int32Of(v) {
                case Some(n) => Ok(Some(n))
                case None    => parseInt(name, SqlValue.textOf(v)) |> Result.map(Some)
            })

    /// A mini-sector column arrives as the JSON array it was written as.
    pub def optionalIntArray(expr: String): Sel[Option[List[Option[Int32]]]] =
        cell(raw(expr), (name, v) ->
            if (SqlValue.isNull(v)) Ok(None)
            else parseIntArray(name, SqlValue.textOf(v)) |> Result.map(Some))

    /// The failure a cell that carries nothing is, in the words the reading has
    /// always used for one.
    def nonNull(name: String, value: SqlValue): Result[DbErrorKind, SqlValue] =
        if (SqlValue.isNull(value)) Err(DbErrorKind.DecodeError(name, "was null")) else Ok(value)

    def parseInt(expr: String, text: String): Result[DbErrorKind, Int32] =
        Int32.fromString(text) |> Option.toOk(DbErrorKind.DecodeError(expr, "is not a number: \"${text}\""))

    def parseIntArray(expr: String, text: String): Result[DbErrorKind, List[Option[Int32]]] =
        match String.stripPrefix({substr = "["}, text) |> Option.flatMap(String.stripSuffix({substr = "]"})) {
            case None       => Err(DbErrorKind.DecodeError(expr, "is not a JSON array: \"${text}\""))
            case Some("")   => Ok(Nil)
            case Some(body) =>
                String.splitOn({substr = ","}, body) |> Result.traverse(element -> match element {
                    case "null" => Ok(None)
                    case value  => parseInt(expr, value) |> Result.map(n -> Some(n))
                })
        }

    pub def andThen(transform: a -> Result[DbErrorKind, b], sel: Sel[a]): Sel[b] =
        let Sel.Sel(columns, decodeCells) = sel;
        Sel.Sel(columns, cells ->
            decodeCells(cells) |> Result.flatMap(match (value, rest) ->
                transform(value) |> Result.map(converted -> (converted, rest))
            )
        )

    def both(selA: Sel[a], selB: Sel[b]): Sel[(a, b)] =
        let Sel.Sel(columnsA, decodeA) = selA;
        let Sel.Sel(columnsB, decodeB) = selB;
        Sel.Sel(columnsA ++ columnsB, cells ->
            decodeA(cells) |> Result.flatMap(match (a, restA) ->
                decodeB(restA) |> Result.map(match (b, restB) -> ((a, b), restB))
            )
        )

    def selMap(transform: a -> b, sel: Sel[a]): Sel[b] =
        andThen(value -> Ok(transform(value)), sel)

    pub def clause(sel: Sel[a]): Frag =
        frags(raw("SELECT") :: columnsOf(sel) :: Nil)

    /// The expressions a projection names, as the `SELECT` clause spells them and
    /// without the keyword -- the piece a statement written out puts between
    /// `SELECT` and `FROM`.
    pub def columnsOf(p: p): Frag with Project[p] =
        let Sel.Sel(columns, _) = Project.sel(p);
        joinFrags(", ", columns)

    /// The labels a projection's columns come back under, in the order the clause
    /// writes them.
    pub def labels(sel: Sel[a]): List[String] =
        let Sel.Sel(columns, _) = sel;
        columns |> List.map(column -> { let Frag.Frag(text, _) = column; label(text) })

    /// The row a query reads: its cells put in the order the projection names
    /// them, and then read as the projection reads them.
    pub def decode(sel: Sel[a], row: Row): Result[DbErrorKind, a] =
        let Sel.Sel(_, decodeCells) = sel;
        let names = labels(sel);
        let width = List.length(names);
        if (width != Row.size(row))
            Err(DbErrorKind.SchemaMismatch(
                "the projection names ${width} columns and the row carries ${Row.size(row)}"))
        else
            align(names, List.zip(Row.columnNames(row), Row.cells(row)))
                |> Result.flatMap(cells -> decodeCells(Row.ofCells(cells)))
                |> Result.map(match (value, _) -> value)

    /// The label a projection comes back under.
    ///
    /// SQLite answers a column named through its qualifier by the name alone --
    /// `SELECT l.key` comes back under `key` -- and an expression by the very
    /// text it was written with, spaces and all. So the text that goes into the
    /// clause is the key into the row that comes back, which is what lets the
    /// clause and the reading stay the one value.
    def label(text: String): String =
        match aliasOf(text) {
            case Some(name) => name
            case None       => match qualified(text) {
                case Some(name) => name
                case None       => text
            }
        }

    /// `expr AS name` comes back under `name`.
    ///
    /// The last ` AS ` anywhere in the text, so a projection written as a
    /// subquery that aliases something inside itself is labelled by that inner
    /// name rather than by the whole text. Nothing declared is written that way;
    /// a column authored as a subquery has to be read at the name its own `AS`
    /// gives it.
    def aliasOf(text: String): Option[String] =
        match List.reverse(String.splitOn({substr = " AS "}, text)) {
            case Nil       => None
            case _ :: Nil  => None
            case name :: _ => Some(String.trim(name))
        }

    /// `qualifier.name` comes back under `name`. Only a text that is nothing but
    /// the two, since `m.key + 1` comes back as the whole of it.
    def qualified(text: String): Option[String] =
        match String.splitOn({substr = "."}, text) {
            case qualifier :: name :: Nil if isName(qualifier) and isName(name) => Some(name)
            case _                                                                => None
        }

    def isName(text: String): Bool =
        not String.isEmpty(text)
            and (String.toList(text)
                |> List.forAll(c -> Char.isLetter(c) or Char.isDigit(c) or c == '_'))

    /// The cells the projection names, taken out of the row in that order. A
    /// projection taking a label the row does not carry fails by naming itself.
    ///
    /// Two projections under one label -- a join naming both sides' `elapsed_ms`
    /// -- are answered in the order the clause writes them, which is the one
    /// order the row cannot contradict.
    def align(
        names: List[String],
        given: List[(String, SqlValue)]
    ): Result[DbErrorKind, List[SqlValue]] =
        match names {
            case Nil => Ok(Nil)
            case name :: rest => match take(name, given, Nil) {
                case None                 => Err(DbErrorKind.SchemaMismatch(
                    "no column of the row answers to the projected `${name}`"))
                case Some((cell, left))   => align(rest, left) |> Result.map(more -> cell :: more)
            }
        }

    /// The cell under `name`, and the pairs that are left with it gone. The ones
    /// walked past keep their place.
    def take(
        name: String,
        given: List[(String, SqlValue)],
        passed: List[(String, SqlValue)]
    ): Option[(SqlValue, List[(String, SqlValue)])] =
        match given {
            case Nil                          => None
            case (head, cell) :: rest         =>
                if (head == name)
                    Some((cell, List.append(List.reverse(passed), rest)))
                else
                    take(name, rest, (head, cell) :: passed)
        }

    ///
    /// ===== PROJECTIONS =====
    ///

    /// What a query may project: a reading, or a tuple of them. A tuple is
    /// read as the tuple of what its parts read, so the clause and the value
    /// that comes back are two readings of the one expression the caller
    /// wrote.
    pub trait Project[t] {
        type Out
        pub def sel(x: t): Sel[Project.Out[t]]
    }

    instance Project[Sel[a]] {
        type Out = a
        pub def sel(x: Sel[a]): Sel[a] = x
    }

    /// A reading of the far side of a `LEFT JOIN`: nothing where the join
    /// found no row, which is every cell the reading takes coming back null.
    /// A column that is null in its own right reads as nothing either way, so
    /// this is for the ones that are not.
    pub def orNull(pick: p): Sel[Option[Project.Out[p]]] with Project[p] =
        let Sel.Sel(columns, decodeCells) = Project.sel(pick);
        let width = List.length(columns);
        Sel.Sel(columns, row ->
            if (width > 0 and Row.size(row) >= width and Row.allNull(row, width))
                Ok((None, Row.drop(row, width)))
            else
                decodeCells(row) |> Result.map(match (value, rest) -> (Some(value), rest))
        )

    /// A reading of a record, extended a field at a time: `add` names the
    /// field the cell lands in, and a field left out is a record the type does
    /// not answer to.
    ///
    /// The same reading as a curried constructor with the readings piped into
    /// it in turn takes the type checker deeper than the stack its thread is
    /// given on Linux, which is smaller than on macOS: twenty-eight columns
    /// compiles on a laptop and overflows in CI.
    pub def record(empty: r): Sel[r] =
        Sel.Sel(Nil, cells -> Ok((empty, cells)))

    /// See `record`. The column is picked as `map` picks one, so a reading
    /// and a column of a declared table both go in.
    pub def field(pick: p, add: (r, Project.Out[p]) -> s, rest: Sel[r]): Sel[s] with Project[p] =
        both(rest, Project.sel(pick)) |> selMap(match (r, value) -> add(r, value))

    ///
    /// ===== AGGREGATES AND WINDOWS =====
    ///
    /// An aggregate or a window is written over a projection and read back as that
    /// projection reads, which is what `Project` already says how to do: `min(c#s1Ms)`
    /// reads as an `Option[Int32]` because `s1_ms` is one.
    ///
    /// The reading is carried through; only the text is wrapped.
    ///

    /// The pieces a list is made of, separated as SQL separates them.
    pub def joined(pieces: List[Frag]): Frag =
        joinFrags(", ", pieces)

    /// The piece of a statement a projection contributes, values and all.
    pub def fragment(sel: Sel[a]): Frag =
        joinFrags(", ", selColumns(sel))

    def selColumns(sel: Sel[a]): List[Frag] =
        let Sel.Sel(columns, _) = sel;
        columns

    /// Pieces run together with nothing between them, where the text itself puts the
    /// separation -- inside a function's parentheses, around a window's.
    def glued(pieces: List[Frag]): Frag =
        joinFrags("", pieces)

    /// The function named, over what `arg` is.
    def call(name: String, arg: Sel[a]): Sel[a] =
        let Sel.Sel(_, decode) = arg;
        Sel.Sel(glued(raw("${name}(") :: joinFrags(", ", selColumns(arg)) :: raw(")") :: Nil) :: Nil, decode)

    pub def sum(p: p): Sel[Project.Out[p]] with Project[p] = call("SUM", Project.sel(p))
    pub def min(p: p): Sel[Project.Out[p]] with Project[p] = call("MIN", Project.sel(p))
    pub def max(p: p): Sel[Project.Out[p]] with Project[p] = call("MAX", Project.sel(p))
    pub def firstValue(p: p): Sel[Project.Out[p]] with Project[p] = call("FIRST_VALUE", Project.sel(p))

    /// A count is never null and never the argument's type, so it is the one aggregate
    /// whose reading is its own.
    pub def count(p: p): Sel[Int32] with Project[p] =
        intOf(glued(raw("COUNT(") :: joinFrags(", ", selColumns(Project.sel(p))) :: raw(")") :: Nil))

    /// The same columns read as possibly nothing.
    ///
    /// Two things answer with a null the argument's own type does not predict: an
    /// aggregate over a group holding no rows, and the predecessor `lag` names for the
    /// first row of a window.
    pub def opt(p: p): Sel[Option[Project.Out[p]]] with Project[p] =
        let Sel.Sel(columns, decode) = Project.sel(p);
        Sel.Sel(columns, row -> match List.head(Row.cells(row)) {
            case Some(value) if SqlValue.isNull(value) => Ok((None, Row.drop(row, 1)))
            case _ => decode(row) |> Result.map(match (value, rest) -> (Some(value), rest))
        })

    /// `COALESCE`, the nullable side first.
    ///
    /// The reading is the fallback's, which is what answers when the first side carries
    /// nothing.
    pub def coalesce(nullable: Sel[Option[a]], fallback: Sel[a]): Sel[a] =
        let Sel.Sel(_, decode) = fallback;
        Sel.Sel(
            glued(
                raw("COALESCE(") :: joinFrags(", ", selColumns(nullable)) ::
                raw(", ") :: joinFrags(", ", selColumns(fallback)) :: raw(")") :: Nil
            ) :: Nil,
            decode
        )

    /// A projected expression under the name the query gives it.
    pub def aliased(name: String, sel: Sel[a]): Frag =
        frags(joinFrags(", ", selColumns(sel)) :: raw("AS ${name}") :: Nil)

    // ------------------------------------------------------------------ windows

    /// How far a window reaches from the row being read.
    pub enum Frame {
        case UnboundedPreceding
        case Preceding(Int32)
        case CurrentRow
        case Following(Int32)
        case UnboundedFollowing
    }

    /// What a window is: the name the query gives it when it reads the window more
    /// than once, the rows it is split into, the order it walks them in, and how far
    /// it reaches.
    ///
    /// A name set means the clauses are spelled once, in the `WINDOW` clause, and every
    /// use refers back to it.
    pub type alias Window = {
        name      = Option[String],
        partition = List[Frag],
        order     = List[Frag],
        frame     = Option[Frag]
    }

    /// A window read once: spelled where it is used.
    pub def window(partition: List[Frag], order: List[Frag], frame: Option[Frag]): Window =
        { name = None, partition = partition, order = order, frame = frame }

    /// A window read more than once: named, spelled once, and referred to by that name
    /// everywhere else.
    pub def namedWindow(
        name: String,
        partition: List[Frag],
        order: List[Frag],
        frame: Option[Frag]
    ): Window =
        { name = Some(name), partition = partition, order = order, frame = frame }

    /// `ROWS BETWEEN ... AND ...`.
    pub def rowsBetween(start: Frame, end: Frame): Option[Frag] =
        Some(raw("ROWS BETWEEN ${textOf(start)} AND ${textOf(end)}"))

    def textOf(frame: Frame): String = match frame {
        case Frame.UnboundedPreceding  => "UNBOUNDED PRECEDING"
        case Frame.Preceding(n)        => "${n} PRECEDING"
        case Frame.CurrentRow          => "CURRENT ROW"
        case Frame.Following(n)        => "${n} FOLLOWING"
        case Frame.UnboundedFollowing  => "UNBOUNDED FOLLOWING"
    }

    /// The clauses between the `OVER (` and its `)`.
    ///
    /// A clause with nothing to say is left out, as every other clause of a query is.
    def overClause(w: Window): Frag =
        let parts =
            (if (List.isEmpty(w#partition)) Nil
             else frags(raw("PARTITION BY") :: joinFrags(", ", w#partition) :: Nil) :: Nil) ++
            (if (List.isEmpty(w#order)) Nil
             else frags(raw("ORDER BY") :: joinFrags(", ", w#order) :: Nil) :: Nil) ++
            (match w#frame { case None => Nil case Some(f) => f :: Nil });
        joinFrags(" ", parts)

    /// What follows `OVER`: the name the query gave the window, or its clauses.
    def overTarget(w: Window): Frag = match w#name {
        case Some(name) => raw("OVER ${name}")
        case None       => glued(raw("OVER (") :: overClause(w) :: raw(")") :: Nil)
    }

    /// The expression, over its window.
    pub def over(p: p, w: Window): Sel[Project.Out[p]] with Project[p] =
        let Sel.Sel(columns, decode) = Project.sel(p);
        Sel.Sel(frags(joinFrags(", ", columns) :: overTarget(w) :: Nil) :: Nil, decode)

    /// `WINDOW w AS (...)`, the clause a named `OVER w` refers back to.
    ///
    /// Nothing for a window no query named.
    pub def windowClause(w: Window): Option[Frag] =
        Option.map(name -> glued(raw("WINDOW ${name} AS (") :: overClause(w) :: raw(")") :: Nil), w#name)

    /// The row's place within its partition, counted from one.
    pub def rowNumber(w: Window): Sel[Int32] =
        intOf(frags(raw("ROW_NUMBER()") :: overTarget(w) :: Nil))

    /// The value the previous row of the window had.
    ///
    /// Nothing for the first row, which is what the reading is an `Option` for.
    pub def lag(p: p, w: Window): Sel[Option[Project.Out[p]]] with Project[p] =
        opt(over(call("LAG", Project.sel(p)), w))

    ///
    /// ===== QUERIES =====
    ///

    /// The clauses of a query, which every stage of building one carries.
    pub type alias Clauses = {
        ctes = List[Frag],
        source = Frag,
        filters = List[Expr[Bool]],
        grouped = List[Frag],
        ordered = List[Frag],
        limited = Option[Int32]
    }

    /// The rows a query reads, before it says what to read of them, and the
    /// columns a projection picks from -- a record of them where the source
    /// has one, `Unit` where it does not.
    pub enum Rows[columns] {
        case Rows(Clauses, columns)
    }

    /// Rows and the reading of one.
    pub enum Query[a] {
        /// The clauses a query was built with, and the reading of them.
        case Built(Clauses, Sel[a])

        /// A statement written out, and the reading of the rows it answers with.
        /// As `Built`, what it projects and what it reads back are one value.
        case Written(Frag, Sel[a])
    }

    /// `source` is what follows `FROM`: a table, a derived table, or tables
    /// joined. It is not read as anything in particular, so what a reading of
    /// it names is the caller's word.
    pub def rows(source: Frag): Rows[Unit] =
        access(source, ())

    /// As `rows`, where the source's columns are declared: `columns` is what
    /// `map` hands the projection, so a column is named rather than spelled.
    pub def access(source: Frag, columns: c): Rows[c] =
        Rows.Rows({
            ctes = Nil,
            source = source,
            filters = Nil,
            grouped = Nil,
            ordered = Nil,
            limited = None
        }, columns)

    /// A common table expression the source is read through, named and
    /// defined but without its `WITH`, which the query writes once however
    /// many there are. Asked twice, both hold.
    pub def using(cte: Frag, rows: Rows[c]): Rows[c] =
        let Rows.Rows(r, columns) = rows;
        Rows.Rows({ ctes = List.append(r#ctes, cte :: Nil) | r }, columns)

    /// What is asked of the rows, asked of the columns the source declared:
    /// a predicate is built from what `map` would be handed, so a column of
    /// another source is not one this query can be scoped by. Asked twice,
    /// both hold.
    pub def filter(predicate: c -> Expr[Bool], rows: Rows[c]): Rows[c] =
        let Rows.Rows(r, columns) = rows;
        Rows.Rows({ filters = List.append(r#filters, predicate(columns) :: Nil) | r }, columns)

    pub def groupBy(terms: List[Frag], rows: Rows[c]): Rows[c] =
        let Rows.Rows(r, columns) = rows;
        Rows.Rows({ grouped = List.append(r#grouped, terms) | r }, columns)

    pub def orderBy(terms: List[Frag], rows: Rows[c]): Rows[c] =
        let Rows.Rows(r, columns) = rows;
        Rows.Rows({ ordered = List.append(r#ordered, terms) | r }, columns)

    pub def limit(count: Int32, rows: Rows[c]): Rows[c] =
        let Rows.Rows(r, columns) = rows;
        Rows.Rows({ limited = Some(count) | r }, columns)

    /// What to read of each row, picked from the source's columns: a column,
    /// or a tuple of columns and expressions. The clause and the value that
    /// comes back are both read off what `pick` returned.
    pub def map(pick: c -> p, rows: Rows[c]): Query[Project.Out[p]] with Project[p] =
        let Rows.Rows(r, columns) = rows;
        Query.Built(r, Project.sel(pick(columns)))

    /// What the row read means, which is the caller's own type rather than
    /// the tuple the columns came back as.
    pub def reading(transform: a -> b, q: Query[a]): Query[b] =
        match q {
            case Query.Built(r, sel)     => Query.Built(r, selMap(transform, sel))
            case Query.Written(sql, sel) => Query.Written(sql, selMap(transform, sel))
        }

    /// What the query is, which is settled without a database.
    pub def toStatement(q: Query[a]): Frag =
        match q {
            case Query.Written(sql, _) => sql
            case Query.Built(r, sel)   => built(r, sel)
        }

    def built(r: Clauses, sel: Sel[a]): Frag =
        frags(
            keyword("WITH", ", ", r#ctes) ::
            clause(sel) ::
            raw("FROM") ::
            r#source ::
            keyword("WHERE", " AND ", r#filters |> List.map(term)) ::
            keyword("GROUP BY", ", ", r#grouped) ::
            keyword("ORDER BY", ", ", r#ordered) ::
            (match r#limited {
                case Some(n) => raw("LIMIT ${n}")
                case None    => raw("")
            }) :: Nil
        )

    /// A clause is left out rather than written empty, since `GROUP BY` with
    /// nothing after it is not a query.
    def keyword(word: String, separator: String, terms: List[Frag]): Frag =
        if (List.isEmpty(terms))
            raw("")
        else
            frags(raw(word) :: joinFrags(separator, terms) :: Nil)

    ///
    /// ===== STATEMENTS WRITTEN OUT =====
    ///

    /// A statement the caller wrote, and the reading of the rows it answers with.
    ///
    /// `{{name}}` is where each of `holes` goes, and `%%` is where the `SELECT` clause
    /// goes -- which `columnsOf` renders from the projection that reads it back, so a
    /// statement written out names its columns and reads them off the one value, as a
    /// built query does.
    ///
    /// A hole is named rather than counted, so a statement and its pieces disagreeing
    /// says which name is missing, or which name nothing was given for, and not how
    /// many of each there happened to be.
    pub def statement(
        lines: List[String],
        holes: Map[String, Frag],
        projection: p
    ): Query[Project.Out[p]] \ DbErr with Project[p] =
        Query.Written(filled(spaced(lines), holes, columnsOf(projection)), Project.sel(projection))

    /// The statement, the holes filled.
    ///
    /// The template carries no values of its own -- a value goes out bound, which is
    /// why it is a hole and not text -- so the values come out in the order the `?`s
    /// they bind stand in, the `SELECT` clause's own among them.
    def filled(template: String, holes: Map[String, Frag], clause: Frag): Frag \ DbErr =
        match String.splitOn({substr = "%%"}, template) {
            case before :: after :: Nil =>
                let named = holeNames(template);
                let given = holes |> Map.toList |> List.map(match (name, _) -> name);
                let missing = List.filter(name -> not List.exists(k -> k == name, given), named);
                let unused = List.filter(name -> not List.exists(k -> k == name, named), given);
                match (missing, unused) {
                    case (name :: _, _) => DbErr.raise(DbErrorKind.Other(
                        "the statement names `{{${name}}}` and gives nothing for it:"
                            + " ${String.take(120, template)}"
                    ))
                    case (Nil, name :: _) => DbErr.raise(DbErrorKind.Other(
                        "the statement never names `{{${name}}}`: ${String.take(120, template)}"
                    ))
                    case (Nil, Nil) => joinFrags(
                        "",
                        holesFilled(before, holes, template) ::
                        clause ::
                        holesFilled(after, holes, template) ::
                        Nil
                    )
                }
            case _ => DbErr.raise(DbErrorKind.Other(
                "the statement has no `%%` for its SELECT clause: ${String.take(120, template)}"
            ))
        }

    /// A piece of a statement written out, with `{{name}}` where each of `holes` goes
    /// and no clause in it: a common table expression, an arm of a `UNION ALL`, a
    /// scalar subquery.
    pub def spliced(lines: List[String], holes: Map[String, Frag]): Frag \ DbErr =
        let template = spaced(lines);
        let named = holeNames(template);
        let given = holes |> Map.toList |> List.map(match (name, _) -> name);
        let missing = List.filter(name -> not List.exists(k -> k == name, given), named);
        let unused = List.filter(name -> not List.exists(k -> k == name, named), given);
        match (missing, unused) {
            case (name :: _, _) => DbErr.raise(DbErrorKind.Other(
                "the piece names `{{${name}}}` and gives nothing for it:"
                    + " ${String.take(120, template)}"
            ))
            case (Nil, name :: _) => DbErr.raise(DbErrorKind.Other(
                "the piece never names `{{${name}}}`: ${String.take(120, template)}"
            ))
            case (Nil, Nil) => holesFilled(template, holes, template)
        }

    /// The lines of a written statement, or of a piece of one, run together where SQL puts a space.
    ///
    /// Flix has no multi-line string literal, which is why a statement is written one clause per line and put back into one string here.
    pub def spaced(lines: List[String]): String =
        List.join(" ", lines)

    /// Every hole a template names, in the order it names them.
    def holeNames(text: String): List[String] =
        match String.splitOn({substr = "{{"}, text) {
            case Nil       => Nil
            case _ :: Nil  => Nil
            case _ :: rest =>
                match String.splitOn({substr = "}}"}, List.join("{{", rest)) {
                    case Nil          => Nil
                    case name :: more => name :: holeNames(List.join("}}", more))
                }
        }

    /// The text, its named holes spliced in, the values coming out in the order the
    /// `?`s they bind stand in.
    def holesFilled(text: String, holes: Map[String, Frag], template: String): Frag \ DbErr =
        match String.splitOn({substr = "{{"}, text) {
            case Nil          => raw("")
            case only :: Nil  => raw(only)
            case before :: rest =>
                match String.splitOn({substr = "}}"}, List.join("{{", rest)) {
                    case Nil => raw(before)
                    case name :: more =>
                        let Frag.Frag(holeText, holeParams) = Map.getWithDefault(name, raw(""), holes);
                        let Frag.Frag(tailText, tailParams) =
                            holesFilled(List.join("}}", more), holes, template);
                        Frag.Frag(
                            before + holeText + tailText,
                            holeParams ++ tailParams
                        )
                }
        }

    ///
    /// ===== RUNNING =====
    ///

    pub def selectAll(q: Query[a]): List[a] \ DbRead =
        fetched(q) |> List.map(row -> Lite3fx.Sql.orRaise(decode(projectionOf(q), row)))

    /// A query answering with one row, `subject` naming what came back with
    /// none. Named for `select`, which is a keyword.
    pub def selectOne(subject: String, q: Query[a]): a \ DbRead =
        match fetched(q) {
            case row :: _ => Lite3fx.Sql.orRaise(decode(projectionOf(q), row))
            case Nil      => DbErr.raise(DbErrorKind.NoRow(subject))
        }

    def projectionOf(q: Query[a]): Sel[a] =
        match q {
            case Query.Built(_, sel)   => sel
            case Query.Written(_, sel) => sel
        }

    def fetched(q: Query[a]): List[Row] \ DbRead =
        let Frag.Frag(sql, params) = toStatement(q);
        Lite3fx.Sql.fetch(sql, params)

    ///
    /// ===== STATEMENTS =====
    ///

    /// A key a table declares over columns of its own -- the columns
    /// themselves rather than their names, so a key cannot name one the table
    /// has not declared.
    pub enum Key[c] {
        case Primary(List[c])
        case Unique(List[c])
    }

    /// Where a table's rows live. SQLite's default keeps them in a tree of an
    /// integer of its own and a declared primary key in a second tree over
    /// them; `WithoutRowid` keeps them in the primary key's own tree, and so
    /// needs the table to declare one.
    pub enum Storage {
        case Rowid
        case WithoutRowid
    }

    /// The key over the columns as another view of them has them -- the
    /// schema's, where a column is its name and the type it takes and a
    /// computed one is too.
    pub def mapKey(f: c -> d \ ef, key: Key[c]): Key[d] \ ef =
        match key {
            case Key.Primary(over) => Key.Primary(List.map(f, over))
            case Key.Unique(over)  => Key.Unique(List.map(f, over))
        }

    pub def dropTableIfExists(table: String): String =
        "DROP TABLE IF EXISTS " + table

    /// A column is its name and the type it takes in the table, so a table
    /// that declares its columns has declared its schema. What a column binds
    /// is not read here.
    pub def createTable(
        table: String,
        columns: List[{name = String, sqlType = String | r}],
        keys: List[Key[{name = String, sqlType = String | r}]],
        storage: Storage
    ): String =
        let declared = List.append(
            columns |> List.map(c -> "${c#name} ${c#sqlType}"),
            keys |> List.map(keyText)
        );
        "CREATE TABLE " + table + " (\n"
            + (declared |> List.map(d -> "  ${d}") |> List.join(",\n"))
            + "\n)" + storageText(storage)

    /// A tree over columns the key does not lead with, which is the only way
    /// a query reaching rows by them does not read the table through.
    pub def createIndex(
        name: String,
        table: String,
        over: List[{name = String | r}]
    ): String =
        "CREATE INDEX " + name + " ON " + table + " (" + names(over) + ")"

    def storageText(storage: Storage): String =
        match storage {
            case Storage.Rowid        => ""
            case Storage.WithoutRowid => " WITHOUT ROWID"
        }

    def keyText(key: Key[{name = String | r}]): String =
        match key {
            case Key.Primary(over) => "PRIMARY KEY (" + names(over) + ")"
            case Key.Unique(over)  => "UNIQUE (" + names(over) + ")"
        }

    def names(over: List[{name = String | r}]): String =
        over |> List.map(c -> c#name) |> List.join(", ")

    /// The statement and the rows bound to it, both drawn from the columns in
    /// the order they are given: a row cannot come to be bound in an order the
    /// statement does not name, and there is a `?` for each value and no more.
    pub def insertRows(
        table: String,
        columns: List[{name = String, bind = row -> SqlValue | r}],
        rows: List[row]
    ): (String, List[List[SqlValue]]) =
        let statement = "INSERT INTO " + table
            + " (" + (columns |> List.map(c -> c#name) |> List.join(", ")) + ")"
            + " VALUES (" + (columns |> List.map(_ -> "?") |> List.join(", ")) + ")";
        (statement, rows |> List.map(row -> columns |> List.map(c -> (c#bind)(row))))

    ///
    /// ===== TAGGED BRANCHES =====
    ///

    /// One arm of a `UNION ALL`, and what its rows are about.
    ///
    /// The arm's fragment is the query from its first column onwards: the
    /// label is prepended, so every arm carries it in the same place.
    pub enum Branch[t] {
        /// Every row of the arm is about the same thing.
        case One(t, Frag)

        /// The arm is about `span` things and says which per row, numbering
        /// them from zero.
        case Many({ span = Int32, number = Expr[Int32], tagOf = Int32 -> Option[t] }, Frag)
    }

    /// The arms stacked, each labelled with a number this picks, and a reading
    /// of that number as the thing the arm was about. Neither the arm nor the
    /// reading is written in terms of the number, so the two cannot disagree
    /// about which arm it belongs to.
    ///
    /// `label` names the column the number is carried in, which the caller
    /// orders and partitions by.
    pub def unionAllTagged(label: String, branches: List[Branch[t]]): (Frag, Sel[t]) =
        let numbered = number_(0, branches);
        let rows = numbered
            |> List.map(match (base, branch) -> arm(label, base, branch))
            |> joinFrags(" UNION ALL ");
        let tag = int(label) |> andThen(n ->
            tagOf(numbered, n) |> Option.toOk(DbErrorKind.Other("no arm answers to `${label}` ${n}")));
        (rows, tag)

    def number_(base: Int32, branches: List[Branch[t]]): List[(Int32, Branch[t])] =
        match branches {
            case Nil              => Nil
            case branch :: rest   => (base, branch) :: number_(base + span(branch), rest)
        }

    def span(branch: Branch[t]): Int32 =
        match branch {
            case Branch.One(_, _)     => 1
            case Branch.Many(many, _) => many#span
        }

    def arm(label: String, base: Int32, branch: Branch[t]): Frag =
        match branch {
            case Branch.One(_, sql) =>
                frags(raw("SELECT ${base} AS ${label},") :: sql :: Nil)
            case Branch.Many(many, sql) =>
                frags(
                    raw("SELECT ${base} +") ::
                    term(many#number) ::
                    raw("AS ${label},") ::
                    sql :: Nil
                )
        }

    def tagOf(numbered: List[(Int32, Branch[t])], n: Int32): Option[t] =
        numbered
            |> List.filterMap(match (base, branch) ->
                if (n >= base and n < base + span(branch))
                    match branch {
                        case Branch.One(tag, _)   => Some(tag)
                        case Branch.Many(many, _) => (many#tagOf)(n - base)
                    }
                else
                    None
            )
            |> List.head

    ///
    /// ===== THE TUPLE PROJECTIONS =====
    ///
    /// One per arity, to eight. An instance head takes type variables, so
    /// `(Sel[a], Sel[b])` cannot be one and each arity is written out; a
    /// reading of more than eight columns is a record instead.
    ///

    instance Project[(a, b)] with Project[a], Project[b] {
        type Out = (Project.Out[a], Project.Out[b])
        pub def sel(x: (a, b)): Sel[(Project.Out[a], Project.Out[b])] =
            let (xa, xb) = x;
            let sa = Project.sel(xa);
            let sb = Project.sel(xb);
            both(sa, sb)
    }

    instance Project[(a, b, c)] with Project[a], Project[b], Project[c] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c])
        pub def sel(x: (a, b, c)): Sel[(Project.Out[a], Project.Out[b], Project.Out[c])] =
            let (xa, xb, xc) = x;
            let sa = Project.sel(xa);
            let sb = Project.sel(xb);
            let sc = Project.sel(xc);
            both(sa, both(sb, sc))
                |> selMap(match (va, (vb, vc)) -> (va, vb, vc))
    }

    instance Project[(a, b, c, d)] with Project[a], Project[b], Project[c], Project[d] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d])
        pub def sel(x: (a, b, c, d)): Sel[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d])] =
            let (xa, xb, xc, xd) = x;
            let sa = Project.sel(xa);
            let sb = Project.sel(xb);
            let sc = Project.sel(xc);
            let sd = Project.sel(xd);
            both(sa, both(sb, both(sc, sd)))
                |> selMap(match (va, (vb, (vc, vd))) -> (va, vb, vc, vd))
    }

    instance Project[(a, b, c, d, e)] with Project[a], Project[b], Project[c], Project[d], Project[e] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e])
        pub def sel(x: (a, b, c, d, e)): Sel[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e])] =
            let (xa, xb, xc, xd, xe) = x;
            let sa = Project.sel(xa);
            let sb = Project.sel(xb);
            let sc = Project.sel(xc);
            let sd = Project.sel(xd);
            let se = Project.sel(xe);
            both(sa, both(sb, both(sc, both(sd, se))))
                |> selMap(match (va, (vb, (vc, (vd, ve)))) -> (va, vb, vc, vd, ve))
    }

    instance Project[(a, b, c, d, e, f)] with Project[a], Project[b], Project[c], Project[d], Project[e], Project[f] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f])
        pub def sel(x: (a, b, c, d, e, f)): Sel[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f])] =
            let (xa, xb, xc, xd, xe, xf) = x;
            let sa = Project.sel(xa);
            let sb = Project.sel(xb);
            let sc = Project.sel(xc);
            let sd = Project.sel(xd);
            let se = Project.sel(xe);
            let sf = Project.sel(xf);
            both(sa, both(sb, both(sc, both(sd, both(se, sf)))))
                |> selMap(match (va, (vb, (vc, (vd, (ve, vf))))) -> (va, vb, vc, vd, ve, vf))
    }

    instance Project[(a, b, c, d, e, f, g)] with Project[a], Project[b], Project[c], Project[d], Project[e], Project[f], Project[g] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f], Project.Out[g])
        pub def sel(x: (a, b, c, d, e, f, g)): Sel[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f], Project.Out[g])] =
            let (xa, xb, xc, xd, xe, xf, xg) = x;
            let sa = Project.sel(xa);
            let sb = Project.sel(xb);
            let sc = Project.sel(xc);
            let sd = Project.sel(xd);
            let se = Project.sel(xe);
            let sf = Project.sel(xf);
            let sg = Project.sel(xg);
            both(sa, both(sb, both(sc, both(sd, both(se, both(sf, sg))))))
                |> selMap(match (va, (vb, (vc, (vd, (ve, (vf, vg)))))) -> (va, vb, vc, vd, ve, vf, vg))
    }

    instance Project[(a, b, c, d, e, f, g, h)] with Project[a], Project[b], Project[c], Project[d], Project[e], Project[f], Project[g], Project[h] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f], Project.Out[g], Project.Out[h])
        pub def sel(x: (a, b, c, d, e, f, g, h)): Sel[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f], Project.Out[g], Project.Out[h])] =
            let (xa, xb, xc, xd, xe, xf, xg, xh) = x;
            let sa = Project.sel(xa);
            let sb = Project.sel(xb);
            let sc = Project.sel(xc);
            let sd = Project.sel(xd);
            let se = Project.sel(xe);
            let sf = Project.sel(xf);
            let sg = Project.sel(xg);
            let sh = Project.sel(xh);
            both(sa, both(sb, both(sc, both(sd, both(se, both(sf, both(sg, sh)))))))
                |> selMap(match (va, (vb, (vc, (vd, (ve, (vf, (vg, vh))))))) -> (va, vb, vc, vd, ve, vf, vg, vh))
    }

}
