/// Building the SQL this repository sends, out of the pieces it is made of.
///
/// A `Frag` is a piece of a statement and the values its `?` placeholders bind.
/// An `Expr` is one of those with the type its SQL value has. A `Sel` is one
/// expression of a `SELECT` clause, the label it comes back under and how that
/// cell reads, so a clause is rendered from the readings rather than written
/// beside them, and a column is named once.
///
/// What a query projects is a `Project` -- a reading, a tuple of them, or a
/// sqlfx `Decoder` such as a table's selection -- and it becomes one `Decoder`,
/// whose select list is the clause and whose reading is of the row by label.
pub mod Sql {
    use Sqlitefx.DbErr
    use Sqlitefx.DbError
    use Sqlitefx.DbError.DbErrorKind
    use Sqlitefx.DbRead
    use Sqlitefx.Decoder
    use Sqlitefx.Decoder.Decoder
    use Sqlitefx.Decoder.DecodeError
    use Sqlitefx.RawSql
    use Sqlitefx.Row
    use Sqlitefx.Row.Row
    use Sqlitefx.SqlValue
    use Sqlitefx.SqlValue.SqlValue

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

    /// One expression of a SELECT clause: its text, the label it comes back under, and how the cell under a label reads.
    ///
    /// The label is this side's word, written into the clause as `AS label` wherever it is not the text itself, and the row is read by it through sqlfx's `Decoder`. What SQLite would have called the column unasked is never relied on: it calls `l.key` `key` and an expression by its text, so two sides of a join come back under one name.
    pub enum Sel[a] {
        case Sel(String, String, String -> Decoder[a])
    }

    def sel(expr: String, read: String -> Decoder[a]): Sel[a] =
        Sel.Sel(expr, labelOf(expr), read)

    /// The text a label is made from: a name stays as it is, and anything else keeps its letters, digits and underscores, the runs between them made one underscore. `l1.elapsed_ms` is `l1_elapsed_ms`, and `m.key + 1` is `m_key_1`.
    ///
    /// Two expressions coming to one label is a row with a name twice, which `selectAll` refuses by name.
    def labelOf(text: String): String =
        if (isName(text))
            text
        else {
            let words = String.toList(text)
                |> List.map(c -> if (Char.isLetter(c) or Char.isDigit(c) or c == '_') "${c}" else " ")
                |> List.join("")
                |> String.splitOn({substr = " "})
                |> List.filter(w -> not String.isEmpty(w));
            match words {
                case Nil => "value"
                case first :: _ =>
                    let joined = List.join("_", words);
                    if (String.toList(first) |> List.head |> Option.exists(Char.isDigit)) "c_${joined}" else joined
            }
        }

    def isName(text: String): Bool =
        not String.isEmpty(text)
            and (String.toList(text)
                |> List.forAll(c -> Char.isLetter(c) or Char.isDigit(c) or c == '_'))

    /// The expression under a label of the caller's choosing.
    pub def labelled(label: String, s: Sel[a]): Sel[a] =
        let Sel.Sel(expr, _, read) = s;
        Sel.Sel(expr, label, read)

    /// The expression's text, which is what a statement written out interpolates: a column's name, an aggregate over declared columns, a window's clauses.
    pub def sqlOf(pick: p): String with Pick[p] =
        let Sel.Sel(expr, _, _) = Pick.pick(pick);
        expr

    /// The expression as a piece of a statement, which is what an `ORDER BY` takes.
    pub def fragment(pick: p): Frag with Pick[p] =
        raw(sqlOf(pick))

    /// The reading of a row the expression is one column of.
    pub def decoderOf(s: Sel[a]): Decoder[a] =
        let Sel.Sel(expr, label, read) = s;
        if (expr == label) read(label) else Decoder.selectExpr(expr, read(label))

    /// The text a cell carries, which is how a number SQLite answered in another type is read: a `SUM`, a `json_each` element.
    def cellText(value: SqlValue): String = match value {
        case SqlValue.Str(s)     => s
        case SqlValue.Json(text) => text
        case SqlValue.Int32(n)   => "${n}"
        case SqlValue.Int64(n)   => "${n}"
        case SqlValue.Float64(n) => "${n}"
        case SqlValue.Bool(b)    => if (b) "1" else "0"
        case SqlValue.Null       => ""
        case SqlValue.NullOf(_)  => ""
        case other               => "${other}"
    }

    /// The number a cell carries, where the driver answered it in a wider type than the column holds. Beyond what an `int` column holds there is no number to give, and the answer is none rather than a wrapped-around one.
    def int32Of(value: SqlValue): Option[Int32] = match value {
        case SqlValue.Bool(true)  => Some(1)
        case SqlValue.Bool(false) => Some(0)
        case SqlValue.Int32(_)    => SqlValue.asInt32(value)
        case SqlValue.Int64(_)    => SqlValue.asInt32(value)
        case _                    => Int32.fromString(cellText(value))
    }

    /// A reading's result, raised in the reader's own context.
    pub def orRaise(result: Result[DbErrorKind, a]): a \ {Sqlitefx.TransientDbErr, DbErr} = match result {
        case Ok(value) => value
        case Err(kind) => DbError.raise(kind)
    }

    def textCell(label: String): Decoder[String] =
        Decoder.typed({ name = label, expected = "text" }, v -> Some(cellText(v)))

    def intCell(label: String): Decoder[Int32] =
        Decoder.typed({ name = label, expected = "an integer" }, int32Of)

    /// A truth value is stored as the 1 or 0 the driver bound it as.
    def boolCell(label: String): Decoder[Bool] =
        Decoder.typed({ name = label, expected = "1 or 0" }, v -> match SqlValue.asBool(v) {
            case Some(b) => Some(b)
            case None    => match cellText(v) {
                case "1" => Some(true)
                case "0" => Some(false)
                case _   => None
            }
        })

    /// A mini-sector column holds the JSON array it was written as, a null where the feed left a marker out.
    def intArrayCell(label: String): Decoder[List[Option[Int32]]] =
        Decoder.typed({ name = label, expected = "a JSON array of integers" }, v -> parseIntArray(cellText(v)))

    def parseIntArray(text: String): Option[List[Option[Int32]]] =
        match String.stripPrefix({substr = "["}, text) |> Option.flatMap(String.stripSuffix({substr = "]"})) {
            case None       => None
            case Some("")   => Some(Nil)
            case Some(body) =>
                String.splitOn({substr = ","}, body) |> Option.traverse(element -> match element {
                    case "null" => Some(None)
                    case value  => Int32.fromString(value) |> Option.map(n -> Some(n))
                })
        }

    /// A cell the reading wants as text, which is any cell that is not null: the schema binds text and SQLite keeps what it is given.
    pub def text(expr: String): Sel[String] = sel(expr, textCell)

    pub def optionalText(expr: String): Sel[Option[String]] = sel(expr, l -> Decoder.opt(textCell(l)))

    /// A number the driver answered in another type is read from its text, which is the one form every cell has.
    pub def int(expr: String): Sel[Int32] = sel(expr, intCell)

    pub def optionalInt(expr: String): Sel[Option[Int32]] = sel(expr, l -> Decoder.opt(intCell(l)))

    pub def bool(expr: String): Sel[Bool] = sel(expr, boolCell)

    pub def optionalIntArray(expr: String): Sel[Option[List[Option[Int32]]]] = sel(expr, l -> Decoder.opt(intArrayCell(l)))

    /// What the cell means, where not every value of it means something: a cell `f` has no answer for is the row refused, the column named, and `expected` saying what it should have been.
    pub def refine(expected: String, f: a -> Option[b], s: Sel[a]): Sel[b] with ToString[a] =
        let Sel.Sel(expr, label, read) = s;
        Sel.Sel(expr, label, l -> {
            let Decoder.Decoder(columns, decode) = read(l);
            Decoder.Decoder(columns, row -> decode(row) |> Result.flatMap(value -> match f(value) {
                case Some(meant) => Ok(meant)
                case None        => Err(DecodeError.TypeMismatch(l, expected, "${value}"))
            }))
        })

    ///
    /// ===== PROJECTIONS =====
    ///

    /// One expression a query may project: a reading, or a column a table declares.
    pub trait Pick[t] {
        type Out
        pub def pick(x: t): Sel[Pick.Out[t]]
    }

    instance Pick[Sel[a]] {
        type Out = a
        pub def pick(x: Sel[a]): Sel[a] = x
    }

    /// What a query may project: one expression, a tuple of them, or a `Decoder` -- a record of them, as a table's selection is. The clause and the value that comes back are the one decoder read twice: `Decoder.selectClause` for the one, `Decoder.decodeRow` for the other.
    pub trait Project[t] {
        type Out
        pub def decoder(x: t): Decoder[Project.Out[t]]
    }

    instance Project[Decoder[a]] {
        type Out = a
        pub def decoder(x: Decoder[a]): Decoder[a] = x
    }

    instance Project[Sel[a]] {
        type Out = a
        pub def decoder(x: Sel[a]): Decoder[a] = Sql.decoderOf(x)
    }

    /// The `SELECT` clause of a projection.
    pub def clause(p: p): Frag with Project[p] =
        frags(raw("SELECT") :: columnsOf(p) :: Nil)

    /// The expressions a projection names, as the `SELECT` clause spells them and without the keyword -- the piece a statement written out puts between `SELECT` and `FROM`.
    pub def columnsOf(p: p): Frag with Project[p] =
        raw(Decoder.selectClause(Project.decoder(p)))

    /// A row read as the projection reads it, outside a query: a test's hand-made row.
    pub def decode(p: p, row: Row): Result[DbErrorKind, Project.Out[p]] with Project[p] =
        Decoder.decodeRow(Project.decoder(p), row) |> Result.mapErr(decodeFailure)

    def decodeFailure(error: DecodeError): DbErrorKind =
        DbErrorKind.DecodeError(Decoder.errorColumn(error), Decoder.describeError(error))

    /// The far side of a `LEFT JOIN`, or an aggregate over no rows, or the predecessor `lag` names for a window's first row: nothing where the cell is null, and the expression's own reading where it is not.
    pub def opt(pick: p): Sel[Option[Pick.Out[p]]] with Pick[p] =
        let Sel.Sel(expr, label, read) = Pick.pick(pick);
        Sel.Sel(expr, label, l -> {
            let Decoder.Decoder(columns, decode) = read(l);
            Decoder.Decoder(columns, row -> match Row.get(l, row) {
                case Some(value) if SqlValue.isNull(value) => Ok(None)
                case _ => decode(row) |> Result.map(Some)
            })
        })

    /// See `opt`. A column that is null in its own right reads as nothing either way, so this is for the ones that are not.
    pub def orNull(pick: p): Sel[Option[Pick.Out[p]]] with Pick[p] = opt(pick)

    /// A reading of a record, extended a field at a time: `add` names the field the cell lands in, and a field left out is a record the type does not answer to.
    ///
    /// The same reading as a curried constructor with the readings piped into it in turn takes the type checker deeper than the stack its thread is given on Linux, which is smaller than on macOS: twenty-eight columns compiles on a laptop and overflows in CI.
    pub def record(empty: r): Decoder[r] =
        Decoder.pure(empty)

    /// See `record`. The column is picked as `map` picks one, so a reading and a column of a declared table both go in.
    pub def field(pick: p, add: (r, Project.Out[p]) -> s, rest: Decoder[r]): Decoder[s] with Project[p] =
        both(rest, Project.decoder(pick)) |> Decoder.map(match (r, value) -> add(r, value))

    def both(da: Decoder[a], db: Decoder[b]): Decoder[(a, b)] =
        Decoder.ap(db, Decoder.map(a -> b -> (a, b), da))

    ///
    /// ===== AGGREGATES AND WINDOWS =====
    ///
    /// An aggregate or a window is written over an expression and read back as that expression reads, which is what `Pick` already says how to do: `min(c#s1Ms)` reads as an `Option[Int32]` because `s1_ms` is one. Its label is its own, `min_s1_ms`, so a clause never answers under a column's name with something other than the column.
    ///

    /// The pieces a list is made of, separated as SQL separates them.
    pub def joined(pieces: List[Frag]): Frag =
        joinFrags(", ", pieces)

    /// The function named, over the expression.
    def call(name: String, s: Sel[a]): Sel[a] =
        let Sel.Sel(expr, label, read) = s;
        Sel.Sel("${name}(${expr})", "${String.toLowerCase(name)}_${label}", read)

    pub def sum(p: p): Sel[Pick.Out[p]] with Pick[p] = call("SUM", Pick.pick(p))
    pub def min(p: p): Sel[Pick.Out[p]] with Pick[p] = call("MIN", Pick.pick(p))
    pub def max(p: p): Sel[Pick.Out[p]] with Pick[p] = call("MAX", Pick.pick(p))
    pub def firstValue(p: p): Sel[Pick.Out[p]] with Pick[p] = call("FIRST_VALUE", Pick.pick(p))

    /// A count is never null and never the argument's type, so it is the one aggregate whose reading is its own.
    pub def count(p: p): Sel[Int32] with Pick[p] =
        let Sel.Sel(expr, label, _) = Pick.pick(p);
        Sel.Sel("COUNT(${expr})", "count_${label}", intCell)

    /// `COALESCE`, the nullable side first.
    ///
    /// The reading is the fallback's, which is what answers when the first side carries nothing.
    pub def coalesce(nullable: Sel[Option[a]], fallback: Sel[a]): Sel[a] =
        let Sel.Sel(first, _, _) = nullable;
        let Sel.Sel(second, label, read) = fallback;
        Sel.Sel("COALESCE(${first}, ${second})", "coalesce_${label}", read)

    // ------------------------------------------------------------------ windows

    /// How far a window reaches from the row being read.
    pub enum Frame {
        case UnboundedPreceding
        case Preceding(Int32)
        case CurrentRow
        case Following(Int32)
        case UnboundedFollowing
    }

    /// What a window is: the name the query gives it when it reads the window more than once, the rows it is split into, the order it walks them in, and how far it reaches.
    ///
    /// A name set means the clauses are spelled once, in the `WINDOW` clause, and every use refers back to it.
    ///
    /// The terms are text, since a window is spelled inside an expression of the `SELECT` clause, which binds nothing.
    pub type alias Window = {
        name      = Option[String],
        partition = List[String],
        order     = List[String],
        frame     = Option[String]
    }

    /// A window read once: spelled where it is used.
    pub def window(partition: List[String], order: List[String], frame: Option[String]): Window =
        { name = None, partition = partition, order = order, frame = frame }

    /// A window read more than once: named, spelled once, and referred to by that name everywhere else.
    pub def namedWindow(
        name: String,
        partition: List[String],
        order: List[String],
        frame: Option[String]
    ): Window =
        { name = Some(name), partition = partition, order = order, frame = frame }

    /// `ROWS BETWEEN ... AND ...`.
    pub def rowsBetween(start: Frame, end: Frame): Option[String] =
        Some("ROWS BETWEEN ${textOf(start)} AND ${textOf(end)}")

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
    def overClause(w: Window): String =
        let parts =
            (if (List.isEmpty(w#partition)) Nil
             else "PARTITION BY ${List.join(", ", w#partition)}" :: Nil) ++
            (if (List.isEmpty(w#order)) Nil
             else "ORDER BY ${List.join(", ", w#order)}" :: Nil) ++
            (match w#frame { case None => Nil case Some(f) => f :: Nil });
        List.join(" ", parts)

    /// What follows `OVER`: the name the query gave the window, or its clauses.
    def overTarget(w: Window): String = match w#name {
        case Some(name) => "OVER ${name}"
        case None       => "OVER (${overClause(w)})"
    }

    /// The label part a window adds: its name, where it has one.
    def overLabel(w: Window): String = match w#name {
        case Some(name) => "over_${labelOf(name)}"
        case None       => "over"
    }

    /// The expression, over its window.
    pub def over(p: p, w: Window): Sel[Pick.Out[p]] with Pick[p] =
        let Sel.Sel(expr, label, read) = Pick.pick(p);
        Sel.Sel("${expr} ${overTarget(w)}", "${label}_${overLabel(w)}", read)

    /// `WINDOW w AS (...)`, the clause a named `OVER w` refers back to.
    ///
    /// Nothing for a window no query named.
    pub def windowClause(w: Window): Option[Frag] =
        Option.map(name -> raw("WINDOW ${name} AS (${overClause(w)})"), w#name)

    /// The row's place within its partition, counted from one.
    pub def rowNumber(w: Window): Sel[Int32] =
        Sel.Sel("ROW_NUMBER() ${overTarget(w)}", "row_number_${overLabel(w)}", intCell)

    /// The value the previous row of the window had.
    ///
    /// Nothing for the first row, which is what the reading is an `Option` for.
    pub def lag(p: p, w: Window): Sel[Option[Pick.Out[p]]] with Pick[p] =
        opt(over(call("LAG", Pick.pick(p)), w))

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
        case Built(Clauses, Decoder[a])

        /// A statement written out, and the reading of the rows it answers with.
        /// As `Built`, what it projects and what it reads back are one value.
        case Written(Frag, Decoder[a])
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
        Query.Built(r, Project.decoder(pick(columns)))

    /// What the row read means, which is the caller's own type rather than
    /// the tuple the columns came back as.
    pub def reading(transform: a -> b, q: Query[a]): Query[b] =
        match q {
            case Query.Built(r, d)     => Query.Built(r, Decoder.map(transform, d))
            case Query.Written(sql, d) => Query.Written(sql, Decoder.map(transform, d))
        }

    /// What the query is, which is settled without a database.
    pub def toStatement(q: Query[a]): Frag =
        match q {
            case Query.Written(sql, _) => sql
            case Query.Built(r, d)     => built(r, d)
        }

    def built(r: Clauses, d: Decoder[a]): Frag =
        frags(
            keyword("WITH", ", ", r#ctes) ::
            clause(d) ::
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
        Query.Written(filled(spaced(lines), holes, columnsOf(projection)), Project.decoder(projection))

    /// The statement, the holes filled.
    ///
    /// The template carries no values of its own -- a value goes out bound, which is
    /// why it is a hole and not text -- so the values come out in the order the `?`s
    /// they bind stand in, the `SELECT` clause's own among them.
    def filled(template: String, holes: Map[String, Frag], clause: Frag): Frag \ DbErr =
        refuseLineComment("the statement", template);
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
                    case (Nil, Nil) =>
                        let written = joinFrags(
                            "",
                            holesFilled(before, holes, template) ::
                            clause ::
                            holesFilled(after, holes, template) ::
                            Nil
                        );
                        refuseUnscoped(template, written);
                        written
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
        refuseLineComment("the piece", template);
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

    /// A written statement holds no `--`.
    ///
    /// The run together is what makes this worth a check: a clause per line reads as a
    /// place a comment belongs, and `spaced` puts the statement back onto one line, so
    /// the comment reaches the database still open. What it deletes behind itself is not
    /// a syntax error -- the statement still runs, and answers with the wrong rows in
    /// the wrong order, and the bound values still count out. A `/* */` survives the
    /// run together and is what to write instead.
    def refuseLineComment(place: String, template: String): Unit \ DbErr =
        if (String.contains({substr = "--"}, template))
            DbErr.raise(DbErrorKind.Other(
                "${place} holds a `--`, and its lines are run together into one, so the comment"
                    + " reaches the database still open and has commented out every clause behind"
                    + " it: ${String.take(120, template)}"
            ))
        else
            ()

    /// A written statement binds at least one value.
    ///
    /// Every one of them narrows to a round, and the only way any of them does it is by
    /// binding that round's id -- through `Laps.scope` or `Rounds.scope` directly, or
    /// through a piece that does. So a statement binding nothing reads every round the
    /// database holds, and no other check can see it: there is no hole left unfilled, the
    /// statement is well formed, and it fails only by answering with another round's
    /// rows -- which on a database holding one round is not even visible.
    ///
    /// What this catches is a statement that names no round at all. A statement binding
    /// some other value and no round id still reads every round, and still passes; the
    /// rule is a tripwire on the mistake already made, not a proof of the scope.
    def refuseUnscoped(template: String, written: Frag): Unit \ DbErr =
        let Frag.Frag(_, values) = written;
        if (List.isEmpty(values))
            DbErr.raise(DbErrorKind.Other(
                "the statement binds no value, so it names no round and reads every round the"
                    + " database holds -- the scope is not one of the holes, it is a value:"
                    + " ${String.take(120, template)}"
            ))
        else
            ()

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

    pub def selectAll(q: Query[a]): List[a] \ DbRead + RawSql =
        let d = projectionOf(q);
        fetched(q) |> List.map(row -> Sql.orRaise(decode(d, row)))

    /// A query answering with one row, `subject` naming what came back with
    /// none. Named for `select`, which is a keyword.
    pub def selectOne(subject: String, q: Query[a]): a \ DbRead + RawSql =
        match fetched(q) {
            case row :: _ => Sql.orRaise(decode(projectionOf(q), row))
            case Nil      => DbErr.raise(DbErrorKind.Other("${subject} came back with no row"))
        }

    def projectionOf(q: Query[a]): Decoder[a] =
        match q {
            case Query.Built(_, d)   => d
            case Query.Written(_, d) => d
        }

    /// A row is read by name, so a name the row carries twice is a column the reading cannot tell from the other: the query is refused. A row's names are a map, so a name given twice shows as fewer names than cells.
    def unambiguous(rows: List[Row]): List[Row] \ DbErr =
        match List.head(rows) {
            case None      => rows
            case Some(row) =>
                let names = Map.size(row#columns);
                let cells = Vector.length(row#cells);
                if (names < cells)
                    DbErr.raise(DbErrorKind.SchemaMismatch(
                        "the row carries ${cells} columns under ${names} names, so a reading by name cannot tell them apart"))
                else
                    rows
        }

    def fetched(q: Query[a]): List[Row] \ DbRead + RawSql =
        let (sql, params) = numbered(toStatement(q));
        unambiguous(Sqlitefx.Sql.fetch(sql, params))

    /// The statement as sqlfx takes it: each `?` outside a quoted string becomes `$1`, `$2`, ... in the order the values were bound.
    ///
    /// A piece keeps its `?`s, since where its values fall among the statement's is known only once the pieces are joined.
    pub def numbered(fragment: Frag): (String, List[SqlValue]) =
        let Frag.Frag(sql, params) = fragment;
        let text = region rc {
            let sb = StringBuilder.empty(rc);
            discard String.toList(sql) |> List.foldLeft((acc, ch) -> {
                let (next, inQuote) = acc;
                if (ch == '?' and not inQuote) {
                    StringBuilder.append("$${next}", sb);
                    (next + 1, inQuote)
                } else {
                    StringBuilder.append(ch, sb);
                    (next, if (ch == '\'') not inQuote else inQuote)
                }
            }, (1, false));
            StringBuilder.toString(sb)
        };
        (text, params)

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
    /// statement does not name, and there is a `$n` for each value and no more.
    pub def insertRows(
        table: String,
        columns: List[{name = String, bind = row -> SqlValue | r}],
        rows: List[row]
    ): Option[(String, List[SqlValue])] =
        if (List.isEmpty(rows))
            None
        else {
            let width = List.length(columns);
            let group = i -> "(" + (List.range(1, width + 1) |> List.map(c -> "$${i * width + c}") |> List.join(", ")) + ")";
            let statement = "INSERT INTO " + table
                + " (" + (columns |> List.map(c -> c#name) |> List.join(", ")) + ")"
                + " VALUES " + (List.range(0, List.length(rows)) |> List.map(group) |> List.join(", "));
            Some((statement, rows |> List.flatMap(row -> columns |> List.map(c -> (c#bind)(row)))))
        }

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
        let tag = int(label) |> refine("the number of an arm", tagOf(numbered));
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
        pub def decoder(x: (a, b)): Decoder[(Project.Out[a], Project.Out[b])] =
            let (xa, xb) = x;
            let da = Project.decoder(xa);
            let db = Project.decoder(xb);
            both(da, db)
    }

    instance Project[(a, b, c)] with Project[a], Project[b], Project[c] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c])
        pub def decoder(x: (a, b, c)): Decoder[(Project.Out[a], Project.Out[b], Project.Out[c])] =
            let (xa, xb, xc) = x;
            let da = Project.decoder(xa);
            let db = Project.decoder(xb);
            let dc = Project.decoder(xc);
            both(da, both(db, dc))
                |> Decoder.map(match (va, (vb, vc)) -> (va, vb, vc))
    }

    instance Project[(a, b, c, d)] with Project[a], Project[b], Project[c], Project[d] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d])
        pub def decoder(x: (a, b, c, d)): Decoder[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d])] =
            let (xa, xb, xc, xd) = x;
            let da = Project.decoder(xa);
            let db = Project.decoder(xb);
            let dc = Project.decoder(xc);
            let dd = Project.decoder(xd);
            both(da, both(db, both(dc, dd)))
                |> Decoder.map(match (va, (vb, (vc, vd))) -> (va, vb, vc, vd))
    }

    instance Project[(a, b, c, d, e)] with Project[a], Project[b], Project[c], Project[d], Project[e] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e])
        pub def decoder(x: (a, b, c, d, e)): Decoder[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e])] =
            let (xa, xb, xc, xd, xe) = x;
            let da = Project.decoder(xa);
            let db = Project.decoder(xb);
            let dc = Project.decoder(xc);
            let dd = Project.decoder(xd);
            let de = Project.decoder(xe);
            both(da, both(db, both(dc, both(dd, de))))
                |> Decoder.map(match (va, (vb, (vc, (vd, ve)))) -> (va, vb, vc, vd, ve))
    }

    instance Project[(a, b, c, d, e, f)] with Project[a], Project[b], Project[c], Project[d], Project[e], Project[f] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f])
        pub def decoder(x: (a, b, c, d, e, f)): Decoder[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f])] =
            let (xa, xb, xc, xd, xe, xf) = x;
            let da = Project.decoder(xa);
            let db = Project.decoder(xb);
            let dc = Project.decoder(xc);
            let dd = Project.decoder(xd);
            let de = Project.decoder(xe);
            let df = Project.decoder(xf);
            both(da, both(db, both(dc, both(dd, both(de, df)))))
                |> Decoder.map(match (va, (vb, (vc, (vd, (ve, vf))))) -> (va, vb, vc, vd, ve, vf))
    }

    instance Project[(a, b, c, d, e, f, g)] with Project[a], Project[b], Project[c], Project[d], Project[e], Project[f], Project[g] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f], Project.Out[g])
        pub def decoder(x: (a, b, c, d, e, f, g)): Decoder[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f], Project.Out[g])] =
            let (xa, xb, xc, xd, xe, xf, xg) = x;
            let da = Project.decoder(xa);
            let db = Project.decoder(xb);
            let dc = Project.decoder(xc);
            let dd = Project.decoder(xd);
            let de = Project.decoder(xe);
            let df = Project.decoder(xf);
            let dg = Project.decoder(xg);
            both(da, both(db, both(dc, both(dd, both(de, both(df, dg))))))
                |> Decoder.map(match (va, (vb, (vc, (vd, (ve, (vf, vg)))))) -> (va, vb, vc, vd, ve, vf, vg))
    }

    instance Project[(a, b, c, d, e, f, g, h)] with Project[a], Project[b], Project[c], Project[d], Project[e], Project[f], Project[g], Project[h] {
        type Out = (Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f], Project.Out[g], Project.Out[h])
        pub def decoder(x: (a, b, c, d, e, f, g, h)): Decoder[(Project.Out[a], Project.Out[b], Project.Out[c], Project.Out[d], Project.Out[e], Project.Out[f], Project.Out[g], Project.Out[h])] =
            let (xa, xb, xc, xd, xe, xf, xg, xh) = x;
            let da = Project.decoder(xa);
            let db = Project.decoder(xb);
            let dc = Project.decoder(xc);
            let dd = Project.decoder(xd);
            let de = Project.decoder(xe);
            let df = Project.decoder(xf);
            let dg = Project.decoder(xg);
            let dh = Project.decoder(xh);
            both(da, both(db, both(dc, both(dd, both(de, both(df, both(dg, dh)))))))
                |> Decoder.map(match (va, (vb, (vc, (vd, (ve, (vf, (vg, vh))))))) -> (va, vb, vc, vd, ve, vf, vg, vh))
    }

}
