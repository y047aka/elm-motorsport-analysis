/// Building a SELECT out of the readings it is made of.
///
/// A `Sel` is one projection and the decoder that reads it back, held in the
/// same value: the expressions that go into the SELECT clause and the reading
/// of the cells they come back as cannot be added to singly. What a query
/// projects is written as a `Project` -- a reading, or a tuple of them -- so
/// the clause and the value it comes back as are the same value read twice.
///
/// Unlike that decoder, this one stops at the first cell it cannot read: a
/// reading consumes the cells before it, so past a failure there is no longer a
/// position to report the next problem at.
mod Sql {

    use Db.Value

    /// A piece of a query and the values its `?` placeholders bind, kept
    /// together so that concatenating two pieces cannot put a value under the
    /// wrong placeholder.
    pub enum Frag {
        case Frag(String, List[Value])
    }

    /// The expressions of the SELECT clause, and a reading of the cells they
    /// come back as which answers with what is left of the row.
    pub enum Sel[a] {
        case Sel(List[Frag], List[Option[String]] -> Result[String, (a, List[Option[String]])])
    }

    ///
    /// ===== READINGS =====
    ///

    def cell(expr: Frag, read: String -> Option[String] -> Result[String, a]): Sel[a] =
        let Frag.Frag(text, _) = expr;
        Sel.Sel(expr :: Nil, cells -> match cells {
            case c :: rest => read(text, c) |> Result.map(value -> (value, rest))
            case Nil       => Err("the row ended before `${text}`")
        })

    pub def text(expr: String): Sel[String] =
        cell(raw(expr), (name, c) -> c |> Option.toOk("column `${name}` was null"))

    pub def optionalInt(expr: String): Sel[Option[Int32]] =
        optionalIntOf(raw(expr))

    /// As `optionalInt`, where the expression binds values of its own.
    pub def optionalIntOf(expr: Frag): Sel[Option[Int32]] =
        cell(expr, (name, c) -> match c {
            case None       => Ok(None)
            case Some(cell) => parseInt(name, cell) |> Result.map(value -> Some(value))
        })

    pub def int(expr: String): Sel[Int32] =
        intOf(raw(expr))

    /// As `int`, where the expression is one a query built.
    pub def intOf(expr: Frag): Sel[Int32] =
        cell(expr, (name, c) -> forM(
            cell  <- c |> Option.toOk("column `${name}` was null");
            value <- parseInt(name, cell)
        ) yield value)

    /// A truth value is stored as the 1 or 0 the driver bound it as.
    pub def bool(expr: String): Sel[Bool] =
        cell(raw(expr), (name, c) -> forM(
            cell  <- c |> Option.toOk("column `${name}` was null");
            value <- match cell {
                case "1" => Ok(true)
                case "0" => Ok(false)
                case _   => Err("column `${name}` is not a boolean: \"${cell}\"")
            }
        ) yield value)

    /// A mini-sector column arrives as the JSON array it was written as.
    pub def optionalIntArray(expr: String): Sel[Option[List[Option[Int32]]]] =
        cell(raw(expr), (name, c) -> match c {
            case None       => Ok(None)
            case Some(cell) => parseIntArray(name, cell) |> Result.map(values -> Some(values))
        })

    def parseInt(expr: String, text: String): Result[String, Int32] =
        Int32.fromString(text) |> Option.toOk("column `${expr}` is not a number: \"${text}\"")

    def parseIntArray(expr: String, text: String): Result[String, List[Option[Int32]]] =
        match String.stripPrefix({substr = "["}, text) |> Option.flatMap(String.stripSuffix({substr = "]"})) {
            case None       => Err("column `${expr}` is not a JSON array: \"${text}\"")
            case Some("")   => Ok(Nil)
            case Some(body) =>
                String.splitOn({substr = ","}, body) |> Result.traverse(element -> match element {
                    case "null" => Ok(None)
                    case value  => parseInt(expr, value) |> Result.map(n -> Some(n))
                })
        }

    ///
    /// ===== COMPOSING =====
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

    /// A reading of the far side of a `LEFT JOIN`: nothing where the join
    /// found no row, which is every cell the reading takes coming back null.
    /// A column that is null in its own right reads as nothing either way, so
    /// this is for the ones that are not.
    pub def orNull(pick: p): Sel[Option[Project.Out[p]]] with Project[p] =
        let Sel.Sel(columns, decodeCells) = Project.sel(pick);
        let width = List.length(columns);
        Sel.Sel(columns, cells ->
            if (width > 0 and List.length(cells) >= width
                    and List.take(width, cells) |> List.forAll(Option.isEmpty))
                Ok((None, List.drop(width, cells)))
            else
                decodeCells(cells) |> Result.map(match (value, rest) -> (Some(value), rest))
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

    pub def andThen(transform: a -> Result[String, b], sel: Sel[a]): Sel[b] =
        let Sel.Sel(columns, decodeCells) = sel;
        Sel.Sel(columns, cells ->
            decodeCells(cells) |> Result.flatMap(match (value, rest) ->
                transform(value) |> Result.map(converted -> (converted, rest))
            )
        )

    ///
    /// ===== RUNNING =====
    ///

    pub def clause(sel: Sel[a]): Frag =
        let Sel.Sel(columns, _) = sel;
        frags(raw("SELECT") :: joinFrags(", ", columns) :: Nil)

    pub def decode(sel: Sel[a], row: List[Option[String]]): Result[String, a] =
        let Sel.Sel(_, decodeCells) = sel;
        decodeCells(row) |> Result.flatMap(match (value, rest) ->
            if (List.isEmpty(rest))
                Ok(value)
            else
                Err("the row carries ${List.length(rest)} more columns than the projection reads")
        )

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
        case Query(Clauses, Sel[a])
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

    /// What is asked of the rows. Asked twice, both hold.
    pub def filter(predicate: Expr[Bool], rows: Rows[c]): Rows[c] =
        let Rows.Rows(r, columns) = rows;
        Rows.Rows({ filters = List.append(r#filters, predicate :: Nil) | r }, columns)

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
        Query.Query(r, Project.sel(pick(columns)))

    /// What the row read means, which is the caller's own type rather than
    /// the tuple the columns came back as.
    pub def reading(transform: a -> b, q: Query[a]): Query[b] =
        let Query.Query(r, sel) = q;
        Query.Query(r, selMap(transform, sel))

    /// What the query is, which is settled without a database.
    pub def toStatement(q: Query[a]): Frag =
        let Query.Query(r, sel) = q;
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

    pub def selectAll(q: Query[a]): Result[String, List[a]] \ Db =
        let Query.Query(_, sel) = q;
        let Frag.Frag(sql, params) = toStatement(q);
        Db.fetch(sql, params) |> Result.flatMap(Result.traverse(row -> decode(sel, row)))

    /// A query answering with one row, `subject` naming what came back with
    /// none. Named for `select`, which is a keyword.
    pub def selectOne(subject: String, q: Query[a]): Result[String, a] \ Db =
        let Query.Query(_, sel) = q;
        let Frag.Frag(sql, params) = toStatement(q);
        Db.fetch(sql, params) |> Result.flatMap(rows -> match rows {
            case row :: _ => decode(sel, row)
            case Nil      => Err("${subject} came back with no row")
        })

    ///
    /// ===== FRAGMENTS =====
    ///

    /// A piece of a query binding nothing.
    pub def raw(sql: String): Frag =
        Frag.Frag(sql, Nil)

    /// A piece of a query whose `?` placeholders bind `params`, left to right.
    pub def frag(sql: String, params: List[Value]): Frag =
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

    pub def toSql(fragment: Frag): (String, List[Value]) =
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
        Expr.Expr(raw(name))

    pub def i32(value: Int32): Expr[Int32] =
        Expr.Expr(Frag.Frag("?", Value.Integer(value) :: Nil))

    pub def str(value: String): Expr[String] =
        Expr.Expr(Frag.Frag("?", Value.Text(value) :: Nil))

    pub def eq(left: Expr[a], right: Expr[a]): Expr[Bool] = binary("=", left, right)
    pub def ne(left: Expr[a], right: Expr[a]): Expr[Bool] = binary("<>", left, right)
    pub def lte(left: Expr[a], right: Expr[a]): Expr[Bool] = binary("<=", left, right)
    pub def isNotNull(expr: Expr[Option[a]]): Expr[Bool] = postfix("IS NOT NULL", expr)

    /// The predicates, ANDed. None of them is `1 = 1`, which is what a query
    /// with nothing to say about its rows would otherwise carry.
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
            tagOf(numbered, n) |> Option.toOk("no arm answers to `${label}` ${n}"));
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

}
