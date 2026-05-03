/// Type-safe CSV decoders, modelled after BrianHicks/elm-csv's
/// `Csv.Decode` module. Converts a parsed CSV row (a `List[String]`)
/// into a value of an arbitrary type via a small combinator language.
///
/// Declaration order mirrors the original `Csv.Decode` Elm module
/// (BASIC DECODERS / LOCATIONS / RUN DECODERS / MAPPING / FANCY
/// DECODING) so the two implementations can be reviewed side by side.
mod Util.Csv.Decode {

    use Util.Csv.Parser

    ///
    /// ===== BASIC DECODERS =====
    ///

    pub enum Decoder[a] {
        case Decoder((Location, ResolvedNames, Int32, List[String]) -> Result[List[DecodingError], a])
    }

    type alias ResolvedNames = {
        names = Map[String, Int32],
        available = Bool
    }

    def fromString(convert: String -> Result[Problem, a]): Decoder[a] =
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            let mkErr = problem ->
                Err(fieldErr(rowNum, locationToColumn(fieldNames#names, location), problem));
            match location {
                case Location.Column_(colNum) =>
                    match List.nth(colNum, row) {
                        case Some(value) =>
                            match convert(value) {
                                case Ok(converted) => Ok(converted)
                                case Err(p)        => mkErr(p)
                            }
                        case None => mkErr(Problem.ColumnNotFound(colNum))
                    }
                case Location.Field_(name) =>
                    match Map.get(name, fieldNames#names) {
                        case Some(colNum) =>
                            match List.nth(colNum, row) {
                                case Some(value) =>
                                    match convert(value) {
                                        case Ok(converted) => Ok(converted)
                                        case Err(p)        => mkErr(p)
                                    }
                                case None => mkErr(Problem.FieldNotFound(name))
                            }
                        case None => Err(DecodingError.FieldNotProvided(name) :: Nil)
                    }
                case Location.OnlyColumn_ =>
                    match row {
                        case Nil      => mkErr(Problem.ColumnNotFound(0))
                        case x :: Nil =>
                            match convert(x) {
                                case Ok(converted) => Ok(converted)
                                case Err(p)        => mkErr(p)
                            }
                        case _ => mkErr(Problem.ExpectedOneColumn(List.length(row)))
                    }
            }
        )

    /// `fieldErr` is shared by `fromString` and `fail`; the original
    /// inlines this as a local `error` helper inside `fromString`.
    def fieldErr(rowNum: Int32, col: Column, problem: Problem): List[DecodingError] =
        DecodingError.FieldDecodingError(rowNum, col, problem) :: Nil

    pub def string(): Decoder[String] = fromString(s -> Ok(s))

    pub def int(): Decoder[Int32] =
        fromString(value ->
            match Int32.fromString(String.trim(value)) {
                case Some(parsed) => Ok(parsed)
                case None         => Err(Problem.ExpectedInt(value))
            }
        )

    pub def float(): Decoder[Float64] =
        fromString(value ->
            match Float64.fromString(String.trim(value)) {
                case Some(parsed) => Ok(parsed)
                case None         => Err(Problem.ExpectedFloat(value))
            }
        )

    pub def blank(d: Decoder[a]): Decoder[Option[a]] =
        andThen(maybeBlank ->
            if (String.isEmpty(String.trim(maybeBlank))) succeed(None)
            else map(x -> Some(x), d),
            string())

    ///
    /// ===== LOCATIONS =====
    ///

    enum Location {
        case Column_(Int32)
        case Field_(String)
        case OnlyColumn_
    }

    pub def column(col: Int32, d: Decoder[a]): Decoder[a] =
        Decoder.Decoder((_, fieldNames, rowNum, row) ->
            match d {
                case Decoder.Decoder(decoder) =>
                    decoder(Location.Column_(col), fieldNames, rowNum, row)
            }
        )

    pub def optionalColumn(col: Int32, d: Decoder[a]): Decoder[Option[a]] =
        Decoder.Decoder((_, fieldNames, rowNum, row) ->
            if (col < List.length(row))
                match d {
                    case Decoder.Decoder(decoder) =>
                        match decoder(Location.Column_(col), fieldNames, rowNum, row) {
                            case Ok(value) => Ok(Some(value))
                            case Err(es)   => Err(es)
                        }
                }
            else Ok(None)
        )

    pub def field(name: String, d: Decoder[a]): Decoder[a] =
        Decoder.Decoder((_, fieldNames, rowNum, row) ->
            match d {
                case Decoder.Decoder(decoder) =>
                    decoder(Location.Field_(name), fieldNames, rowNum, row)
            }
        )

    pub def optionalField(name: String, d: Decoder[a]): Decoder[Option[a]] =
        Decoder.Decoder((_, fieldNames, rowNum, row) ->
            if (Map.memberOf(name, fieldNames#names))
                match d {
                    case Decoder.Decoder(decoder) =>
                        match decoder(Location.Field_(name), fieldNames, rowNum, row) {
                            case Ok(value) => Ok(Some(value))
                            case Err(es)   => Err(es)
                        }
                }
            else Ok(None)
        )

    pub def availableFields(): Decoder[List[String]] =
        Decoder.Decoder((_, fieldNames, _, _) ->
            if (fieldNames#available)
                Ok(Map.toList(fieldNames#names)
                    |> List.sortBy(p -> match p { case (_, i) => i })
                    |> List.map(p -> match p { case (k, _) => k }))
            else
                Err(DecodingError.NoFieldNamesProvided :: Nil)
        )

    ///
    /// ===== RUN DECODERS =====
    ///

    pub enum FieldNames {
        case NoFieldNames
        case CustomFieldNames(List[String])
        case FieldNamesFromFirstRow
    }

    def getFieldNames(
        headers: FieldNames,
        rows: List[List[String]]
    ): Result[Error, (ResolvedNames, Int32, List[List[String]])] =
        let fromList = names -> {
            let folded = List.foldLeft(
                (state, name) -> match state {
                    case (i, m) => (i + 1, Map.insert(name, i, m))
                },
                (0, Map.empty()),
                names
            );
            match folded { case (_, m) => m }
        };
        match headers {
            case FieldNames.NoFieldNames =>
                Ok(({names = (Map.empty(): Map[String, Int32]), available = false}, 0, rows))
            case FieldNames.CustomFieldNames(names) =>
                Ok(({names = fromList(names), available = true}, 0, rows))
            case FieldNames.FieldNamesFromFirstRow =>
                match rows {
                    case Nil           => Err(Error.NoFieldNamesOnFirstRow)
                    case first :: rest =>
                        Ok(({names = fromList(List.map(String.trim, first)), available = true}, 1, rest))
                }
        }

    pub def decodeCsv(fieldNames: FieldNames, d: Decoder[a], src: String): Result[Error, List[a]] =
        decodeCustom({fieldSeparator = ','}, fieldNames, d, src)

    pub def decodeCustom(
        config: {fieldSeparator = Char},
        fieldNames: FieldNames,
        d: Decoder[a],
        src: String
    ): Result[Error, List[a]] =
        match Parser.parse(config, src) {
            case Err(p)   => Err(Error.ParsingError(p))
            case Ok(rows) => applyDecoder(fieldNames, d, rows)
        }

    def applyDecoder(fieldNames: FieldNames, d: Decoder[a], allRows: List[List[String]]): Result[Error, List[a]] =
        match getFieldNames(fieldNames, allRows) {
            case Err(e) => Err(e)
            case Ok(triple) =>
                match triple {
                    case (resolvedNames, firstRowNumber, rows) =>
                        let folded = List.foldLeft(
                            (acc, row) -> match acc {
                                case (soFar, rowNum) =>
                                    match d {
                                        case Decoder.Decoder(decode) =>
                                            let result = decode(Location.OnlyColumn_, resolvedNames, rowNum, row);
                                            let newSoFar = match (result, soFar) {
                                                case (Ok(val), Ok(values)) => Ok(val :: values)
                                                case (Ok(_),   Err(errs))  => Err(errs)
                                                case (Err(err), Ok(_))     => Err(err :: Nil)
                                                case (Err(err), Err(errs)) => Err(err :: errs)
                                            };
                                            (newSoFar, rowNum + 1)
                                    }
                            },
                            (Ok(Nil), firstRowNumber),
                            rows
                        );
                        match folded {
                            case (Ok(values), _)    => Ok(List.reverse(values))
                            case (Err(errsList), _) =>
                                Err(Error.DecodingErrors(List.flatMap(x -> x, List.reverse(errsList))))
                        }
                }
        }

    pub enum Error with ToString {
        case ParsingError(Parser.Problem)
        case NoFieldNamesOnFirstRow
        case DecodingErrors(List[DecodingError])
    }

    pub enum DecodingError with ToString {
        case FieldDecodingError(Int32, Column, Problem)
        case OneOfDecodingError(Int32, List[DecodingError])
        case FieldNotProvided(String)
        case NoFieldNamesProvided
    }

    pub enum Column with Eq, ToString {
        case Column(Int32)
        case Field(String, Option[Int32])
        case OnlyColumn
    }

    def locationToColumn(names: Map[String, Int32], location: Location): Column =
        match location {
            case Location.Column_(i)   => Column.Column(i)
            case Location.Field_(name) => Column.Field(name, Map.get(name, names))
            case Location.OnlyColumn_  => Column.OnlyColumn
        }

    pub enum Problem with Eq, ToString {
        case ColumnNotFound(Int32)
        case FieldNotFound(String)
        case ExpectedOneColumn(Int32)
        case ExpectedInt(String)
        case ExpectedFloat(String)
        case Failure(String)
    }

    pub def errorToString(e: Error): String =
        match e {
            case Error.ParsingError(p)        => parseProblemToString(p)
            case Error.NoFieldNamesOnFirstRow =>
                "I expected to see field names on the first row, but there were none."
            case Error.DecodingErrors(errs)   =>
                match dedupeErrs(errs) {
                    case Nil =>
                        "Something went wrong, but I got an blank error list so I don't know what it was. Please open an issue!"
                    case only :: Nil =>
                        topLevelErrString(only)
                    case multiple =>
                        "I saw ${List.length(multiple)} problems while decoding this CSV:\n\n" +
                            (multiple |> List.map(topLevelErrString) |> List.join("\n\n"))
                }
        }

    /// ----- `errorToString` helpers -----
    /// In the original elm-csv these are nested `let`-bindings inside
    /// `errorToString`. Flix requires recursive helpers (`isContiguous`,
    /// `dedupeHelp`) at module scope, so all of them are hoisted here.
    def parseProblemToString(p: Parser.Problem): String =
        match p {
            case Parser.Problem.SourceEndedWithoutClosingQuote(row) =>
                "The source ended on row ${row} in a quoted field without a closing quote."
            case Parser.Problem.AdditionalCharactersAfterClosingQuote(row) =>
                "On row ${row} in the source, there were additional characters in a field after a closing quote."
        }

    def problemString(p: Problem): String =
        match p {
            case Problem.ColumnNotFound(i)    => "I couldn't find column #${i}."
            case Problem.FieldNotFound(n)     => "I couldn't find the `${n}` column."
            case Problem.ExpectedOneColumn(i) => "I expected exactly one column, but there were ${i}."
            case Problem.ExpectedInt(s)       => "I could not parse an int from `${s}`."
            case Problem.ExpectedFloat(s)     => "I could not parse a float from `${s}`."
            case Problem.Failure(msg)         => msg
        }

    def columnString(c: Column): String =
        match c {
            case Column.Column(i)         => "column ${i}"
            case Column.Field(n, None)    => "in the `${n}` field"
            case Column.Field(n, Some(i)) => "in the `${n}` field (column ${i})"
            case Column.OnlyColumn        => "column 0 (the only column present)"
        }

    def rowString(startRow: Int32, endRow: Int32): String =
        match endRow - startRow {
            case 0 => "row ${startRow}"
            case 1 => "rows ${startRow} and ${endRow}"
            case _ => "rows ${startRow}–${endRow}"
        }

    def errString(err: DecodingError): String =
        match err {
            case DecodingError.FieldDecodingError(_, c, p) =>
                "${columnString(c)}: ${problemString(p)}"
            case DecodingError.OneOfDecodingError(_, oodes) =>
                "all of the following decoders failed, but at least one must succeed:\n" +
                    (List.zipWithIndex(oodes)
                        |> List.map(pair -> match pair {
                            case (i, e) => "  (${i + 1}) ${errString(e)}"
                        })
                        |> List.join("\n"))
            case DecodingError.FieldNotProvided(name) =>
                "field ${name} was not provided"
            case DecodingError.NoFieldNamesProvided =>
                "Asked for available fields, but none were provided"
        }

    def topLevelErrString(err: {startRow = Int32, endRow = Int32, error = DecodingError}): String =
        (match err#error {
            case DecodingError.FieldDecodingError(_, _, _) =>
                "There was a problem on ${rowString(err#startRow, err#endRow)}, "
            case DecodingError.OneOfDecodingError(_, _) =>
                "There was a problem on ${rowString(err#startRow, err#endRow)} - "
            case DecodingError.FieldNotProvided(_) =>
                "There was a problem in the header: "
            case DecodingError.NoFieldNamesProvided =>
                ""
        }) + errString(err#error)

    def isContiguous(errA: DecodingError, errB: DecodingError): Bool =
        match (errA, errB) {
            case (DecodingError.FieldDecodingError(ra, ca, pa), DecodingError.FieldDecodingError(rb, cb, pb)) =>
                pa == pb and ra + 1 == rb and ca == cb
            case (DecodingError.OneOfDecodingError(aRow, aList), DecodingError.OneOfDecodingError(bRow, bList)) =>
                aRow + 1 == bRow and
                List.length(aList) == List.length(bList) and
                List.zip(aList, bList)
                    |> List.foldLeft((acc, pair) -> match pair { case (a, b) => acc and isContiguous(a, b) }, true)
            case (DecodingError.FieldNotProvided(a), DecodingError.FieldNotProvided(b)) => a == b
            case (DecodingError.NoFieldNamesProvided, DecodingError.NoFieldNamesProvided) => true
            case _ => false
        }

    def getRow(err: DecodingError): Int32 =
        match err {
            case DecodingError.FieldDecodingError(r, _, _) => r
            case DecodingError.OneOfDecodingError(r, _)    => r
            case DecodingError.FieldNotProvided(_)          => 0
            case DecodingError.NoFieldNamesProvided         => 0
        }

    def dedupeHelp(
        soFar: List[{startRow = Int32, endRow = Int32, error = DecodingError}],
        prevGroup: List[DecodingError],
        errors: List[DecodingError]
    ): List[{startRow = Int32, endRow = Int32, error = DecodingError}] =
        match errors {
            case Nil =>
                match prevGroup {
                    case Nil => List.reverse(soFar)
                    case head :: tail =>
                        let startRow = match List.head(List.reverse(tail)) {
                            case Some(first) => getRow(first)
                            case None        => getRow(head)
                        };
                        List.reverse({startRow = startRow, endRow = getRow(head), error = head} :: soFar)
                }
            case err :: rest =>
                match prevGroup {
                    case Nil =>
                        dedupeHelp(soFar, err :: Nil, rest)
                    case head :: tail =>
                        if (isContiguous(head, err))
                            dedupeHelp(soFar, err :: prevGroup, rest)
                        else
                            let startRow = match List.head(List.reverse(tail)) {
                                case Some(first) => getRow(first)
                                case None        => getRow(head)
                            };
                            let newGroup = {startRow = startRow, endRow = getRow(head), error = head};
                            dedupeHelp(newGroup :: soFar, err :: Nil, rest)
                }
        }

    def dedupeErrs(errs: List[DecodingError]): List[{startRow = Int32, endRow = Int32, error = DecodingError}] =
        let sortKey = err -> match err {
            case DecodingError.FieldDecodingError(r, _, p) =>
                match p {
                    case Problem.ColumnNotFound(_)      => (1, "", r)
                    case Problem.FieldNotFound(name)    => (2, name, r)
                    case Problem.ExpectedOneColumn(n)   => (3, "${n}", r)
                    case Problem.ExpectedInt(s)         => (4, s, r)
                    case Problem.ExpectedFloat(s)       => (5, s, r)
                    case Problem.Failure(msg)           => (6, msg, r)
                }
            case DecodingError.OneOfDecodingError(r, lst) => (7, "${List.length(lst)}", r)
            case DecodingError.FieldNotProvided(name)     => (8, name, 0)
            case DecodingError.NoFieldNamesProvided       => (9, "", 0)
        };
        let sorted = List.sortBy(sortKey, errs);
        let grouped = dedupeHelp(Nil, Nil, sorted);
        List.sortBy(g -> g#startRow, grouped)

    ///
    /// ===== MAPPING =====
    ///

    pub def map(f: a -> b, d: Decoder[a]): Decoder[b] =
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            match d {
                case Decoder.Decoder(decoder) =>
                    match decoder(location, fieldNames, rowNum, row) {
                        case Ok(x)   => Ok(f(x))
                        case Err(es) => Err(es)
                    }
            }
        )

    pub def map2(f: (a, b) -> c, da: Decoder[a], db: Decoder[b]): Decoder[c] =
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            match (da, db) {
                case (Decoder.Decoder(decodeA), Decoder.Decoder(decodeB)) =>
                    let ra = decodeA(location, fieldNames, rowNum, row);
                    let rb = decodeB(location, fieldNames, rowNum, row);
                    match (ra, rb) {
                        case (Ok(a), Ok(b))     => Ok(f(a, b))
                        case (Err(a), Err(b))   => Err(List.append(a, b))
                        case (Err(a), _)        => Err(a)
                        case (_, Err(b))        => Err(b)
                    }
            }
        )

    pub def map3(f: (a, b, c) -> d, da: Decoder[a], db: Decoder[b], dc: Decoder[c]): Decoder[d] =
        map2((pair, z) -> match pair { case (x, y) => f(x, y, z) },
             map2((x, y) -> (x, y), da, db),
             dc)

    /// `into` is a Flix reserved word, so the pipeline starter is
    /// renamed to `intoRecord` here.
    pub def intoRecord(f: a -> b): Decoder[a -> b] = succeed(f)

    pub def pipeline(d: Decoder[a], df: Decoder[a -> b]): Decoder[b] =
        map2((g, x) -> g(x), df, d)

    ///
    /// ===== FANCY DECODING =====
    ///

    pub def oneOf(first: Decoder[a], rest: List[Decoder[a]]): Decoder[a] =
        match rest {
            case Nil            => first
            case next :: others => recover(first, oneOf(next, others))
        }

    def recover(first: Decoder[a], second: Decoder[a]): Decoder[a] =
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            match first {
                case Decoder.Decoder(firstF) =>
                    match firstF(location, fieldNames, rowNum, row) {
                        case Ok(value) => Ok(value)
                        case Err(errs) =>
                            match second {
                                case Decoder.Decoder(secondF) =>
                                    match secondF(location, fieldNames, rowNum, row) {
                                        case Ok(value) => Ok(value)
                                        case Err(secondErrs) =>
                                            let problems = match secondErrs {
                                                case DecodingError.OneOfDecodingError(_, ps) :: Nil => ps
                                                case ps                                              => ps
                                            };
                                            Err(DecodingError.OneOfDecodingError(rowNum, List.append(errs, problems)) :: Nil)
                                    }
                            }
                    }
            }
        )

    pub def andThen(next: a -> Decoder[b], d: Decoder[a]): Decoder[b] =
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            match d {
                case Decoder.Decoder(first) =>
                    match first(location, fieldNames, rowNum, row) {
                        case Err(es) => Err(es)
                        case Ok(value) =>
                            match next(value) {
                                case Decoder.Decoder(final) =>
                                    final(location, fieldNames, rowNum, row)
                            }
                    }
            }
        )

    pub def succeed(value: a): Decoder[a] =
        Decoder.Decoder((_, _, _, _) -> Ok(value))

    pub def fail(message: String): Decoder[a] =
        Decoder.Decoder((location, fieldNames, rowNum, _) ->
            Err(fieldErr(rowNum, locationToColumn(fieldNames#names, location), Problem.Failure(message)))
        )

    pub def fromResult(result: Result[String, a]): Decoder[a] =
        match result {
            case Ok(value)    => succeed(value)
            case Err(problem) => fail(problem)
        }

    pub def fromMaybe(problem: String, maybe: Option[a]): Decoder[a] =
        match maybe {
            case Some(value) => succeed(value)
            case None        => fail(problem)
        }

}
