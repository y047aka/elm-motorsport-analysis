/// Building a SELECT out of the readings it is made of.
///
/// A `Sel` is one projection and the decoder that reads it back, held in the
/// same value: the expressions that go into the SELECT clause and the reading
/// of the cells they come back as cannot be added to singly. `Sql.intoRow` and
/// `Sql.pipeline` compose them as `Util.Csv.Decode` composes a row of a CSV.
///
/// Unlike that decoder, this one stops at the first cell it cannot read: a
/// reading consumes the cells before it, so past a failure there is no longer a
/// position to report the next problem at.
mod Sql {

    /// The expressions of the SELECT clause, and a reading of the cells they
    /// come back as which answers with what is left of the row.
    pub enum Sel[a] {
        case Sel(List[String], List[Option[String]] -> Result[String, (a, List[Option[String]])])
    }

    ///
    /// ===== READINGS =====
    ///

    def cell(expr: String, read: Option[String] -> Result[String, a]): Sel[a] =
        Sel.Sel(expr :: Nil, cells -> match cells {
            case c :: rest => read(c) |> Result.map(value -> (value, rest))
            case Nil       => Err("the row ended before `${expr}`")
        })

    pub def optionalText(expr: String): Sel[Option[String]] =
        cell(expr, c -> Ok(c))

    pub def text(expr: String): Sel[String] =
        cell(expr, c -> c |> Option.toOk("column `${expr}` was null"))

    pub def optionalInt(expr: String): Sel[Option[Int32]] =
        cell(expr, c -> match c {
            case None       => Ok(None)
            case Some(text) => parseInt(expr, text) |> Result.map(value -> Some(value))
        })

    pub def int(expr: String): Sel[Int32] =
        cell(expr, c -> forM(
            text  <- c |> Option.toOk("column `${expr}` was null");
            value <- parseInt(expr, text)
        ) yield value)

    /// A truth value is stored as the 1 or 0 the driver bound it as.
    pub def bool(expr: String): Sel[Bool] =
        cell(expr, c -> forM(
            text  <- c |> Option.toOk("column `${expr}` was null");
            value <- match text {
                case "1" => Ok(true)
                case "0" => Ok(false)
                case _   => Err("column `${expr}` is not a boolean: \"${text}\"")
            }
        ) yield value)

    /// A mini-sector column arrives as the JSON array it was written as.
    pub def optionalIntArray(expr: String): Sel[Option[List[Option[Int32]]]] =
        cell(expr, c -> match c {
            case None       => Ok(None)
            case Some(text) => parseIntArray(expr, text) |> Result.map(values -> Some(values))
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

    /// Combine an arbitrary number of readings. Provide a curried function,
    /// then supply each argument with `pipeline`.
    ///
    /// Named for `into`, which is a keyword.
    pub def intoRow(f: a): Sel[a] =
        Sel.Sel(Nil, cells -> Ok((f, cells)))

    /// See `intoRow`.
    pub def pipeline(sel: Sel[a], selFn: Sel[a -> b]): Sel[b] =
        map2((f, value) -> f(value), selFn, sel)

    pub def map(transform: a -> b, sel: Sel[a]): Sel[b] =
        let Sel.Sel(columns, decodeCells) = sel;
        Sel.Sel(columns, cells ->
            decodeCells(cells) |> Result.map(match (value, rest) -> (transform(value), rest))
        )

    pub def map2(transform: (a, b) -> c, selA: Sel[a], selB: Sel[b]): Sel[c] =
        let Sel.Sel(columnsA, decodeA) = selA;
        let Sel.Sel(columnsB, decodeB) = selB;
        Sel.Sel(columnsA ++ columnsB, cells ->
            decodeA(cells) |> Result.flatMap(match (a, restA) ->
                decodeB(restA) |> Result.map(match (b, restB) -> (transform(a, b), restB))
            )
        )

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

    pub def clause(sel: Sel[a]): String =
        let Sel.Sel(columns, _) = sel;
        "SELECT " + List.join(", ", columns)

    pub def decode(sel: Sel[a], row: List[Option[String]]): Result[String, a] =
        let Sel.Sel(_, decodeCells) = sel;
        decodeCells(row) |> Result.flatMap(match (value, rest) ->
            if (List.isEmpty(rest))
                Ok(value)
            else
                Err("the row carries ${List.length(rest)} more columns than the projection reads")
        )

    /// `rest` is the query from `FROM` onwards. The projection comes last, so
    /// a query ends in the runner that says whether it reads one row or all
    /// of them.
    pub def selectAll(rest: String, sel: Sel[a]): Result[String, List[a]] \ Db =
        selectAllWith("", rest, sel)

    /// As `selectAll`, where common table expressions precede the SELECT.
    pub def selectAllWith(ctes: String, rest: String, sel: Sel[a]): Result[String, List[a]] \ Db =
        Db.fetch(prefixed(ctes) + clause(sel) + " " + rest)
            |> Result.flatMap(Result.traverse(row -> decode(sel, row)))

    /// A query answering with one row, `subject` naming what came back with
    /// none. Named for `select`, which is a keyword.
    pub def selectOne(subject: String, rest: String, sel: Sel[a]): Result[String, a] \ Db =
        selectOneWith(subject, "", rest, sel)

    pub def selectOneWith(subject: String, ctes: String, rest: String, sel: Sel[a]): Result[String, a] \ Db =
        Db.fetch(prefixed(ctes) + clause(sel) + " " + rest) |> Result.flatMap(rows -> match rows {
            case row :: _ => decode(sel, row)
            case Nil      => Err("${subject} came back with no row")
        })

    def prefixed(ctes: String): String =
        if (String.isEmpty(ctes)) "" else ctes + " "

}
