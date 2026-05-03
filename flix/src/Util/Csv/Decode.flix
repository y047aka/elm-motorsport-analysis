/// Type-safe CSV decoders, modelled after BrianHicks/elm-csv's
/// `Csv.Decode` module. Converts a parsed CSV row (a `List[String]`)
/// into a value of an arbitrary type via a small combinator language.
///
/// ## Example
///
/// ```flix
/// use Util.Csv.Decode
///
/// let row =
///     Decode.into((name, age) -> {name = name, age = age})
///         |> Decode.pipeline(Decode.column(0, Decode.string()))
///         |> Decode.pipeline(Decode.column(1, Decode.int()))
///
/// Decode.decodeCsv(Decode.FieldNames.NoFieldNames, row, "Alice,30")
/// // => Ok({name = "Alice", age = 30} :: Nil)
/// ```
mod Util.Csv.Decode {

    use Util.Csv.Parser

    ///
    /// Public types
    ///

    /// How field names are obtained for `field`/`optionalField`/`availableFields`.
    pub enum FieldNames {
        case NoFieldNames
        case CustomFieldNames(List[String])
        case FieldNamesFromFirstRow
    }

    /// Identifies a column when reporting an error. Mirrors elm-csv's
    /// `Column` so error messages can describe both positional and
    /// header-based decoders.
    pub enum Column with Eq, ToString {
        case Column(Int32)
        case Field(String, Option[Int32])
        case OnlyColumn
    }

    /// What went wrong on a single field/cell.
    pub enum Problem with Eq, ToString {
        case ColumnNotFound(Int32)
        case FieldNotFound(String)
        case ExpectedOneColumn(Int32)
        case ExpectedInt(String)
        case ExpectedFloat(String)
        case Failure(String)
    }

    /// Per-row decoding errors collected during a `decodeCsv` run.
    pub enum DecodingError with ToString {
        case FieldDecodingError(Int32, Column, Problem)
        case OneOfDecodingError(Int32, List[DecodingError])
        case FieldNotProvided(String)
        case NoFieldNamesProvided
    }

    /// Top-level error returned from `decodeCsv` / `decodeCustom`.
    pub enum Error with ToString {
        case ParsingError(Parser.ParseProblem)
        case NoFieldNamesOnFirstRow
        case DecodingErrors(List[DecodingError])
    }

    /// Opaque decoder. Internally a function from the current
    /// (location, resolved field names, row index, row fields) to either
    /// a value or a list of errors.
    pub enum Decoder[a] {
        case Decoder((Location, ResolvedNames, Int32, List[String]) -> Result[List[DecodingError], a])
    }

    ///
    /// Internal types
    ///

    /// The "where to read from" hint that flows down through combinators.
    /// `OnlyColumn_` is the initial state used at the top level by
    /// `decodeCsv`; `column` and `field` overwrite it for their child.
    enum Location {
        case OnlyColumn_
        case Column_(Int32)
        case Field_(String)
    }

    /// Resolved field names, if any. `None` means the user passed
    /// `NoFieldNames` and so `field`/`optionalField` cannot work.
    type alias ResolvedNames = {
        fieldNames = Option[Map[String, Int32]]
    }

    ///
    /// Primitive decoders
    ///

    /// Decodes a field as a `String`. Always succeeds when the field
    /// is reachable.
    pub def string(): Decoder[String] =
        Decoder.Decoder((loc, names, rowIdx, row) ->
            getField(loc, names, rowIdx, row)
        )

    /// Decodes a field as an `Int32`. Fails with `ExpectedInt` if the
    /// raw cell text is not parseable.
    pub def int(): Decoder[Int32] =
        Decoder.Decoder((loc, names, rowIdx, row) ->
            match getField(loc, names, rowIdx, row) {
                case Err(es) => Err(es)
                case Ok(s) =>
                    match Int32.fromString(s) {
                        case Some(n) => Ok(n)
                        case None    => Err(fieldErr(rowIdx, locToColumn(loc, names), Problem.ExpectedInt(s)))
                    }
            }
        )

    /// Decodes a field as a `Float64`. Fails with `ExpectedFloat` if
    /// the raw cell text is not parseable.
    pub def float(): Decoder[Float64] =
        Decoder.Decoder((loc, names, rowIdx, row) ->
            match getField(loc, names, rowIdx, row) {
                case Err(es) => Err(es)
                case Ok(s) =>
                    match Float64.fromString(s) {
                        case Some(f) => Ok(f)
                        case None    => Err(fieldErr(rowIdx, locToColumn(loc, names), Problem.ExpectedFloat(s)))
                    }
            }
        )

    /// Treats whitespace-only cells as `None` and otherwise applies
    /// the inner decoder, wrapping the result in `Some`.
    pub def blank(d: Decoder[a]): Decoder[Option[a]] =
        Decoder.Decoder((loc, names, rowIdx, row) ->
            match getField(loc, names, rowIdx, row) {
                case Err(es) => Err(es)
                case Ok(s) =>
                    if (String.isEmpty(String.trim(s))) Ok(None)
                    else
                        match d {
                            case Decoder.Decoder(f) =>
                                match f(loc, names, rowIdx, row) {
                                    case Ok(x)   => Ok(Some(x))
                                    case Err(es) => Err(es)
                                }
                        }
            }
        )

    /// Returns the list of header names available to `field` decoders.
    /// Fails with `NoFieldNamesProvided` if no field names were resolved.
    pub def availableFields(): Decoder[List[String]] =
        Decoder.Decoder((_, names, _, _) ->
            match names#fieldNames {
                case None    => Err(DecodingError.NoFieldNamesProvided :: Nil)
                case Some(m) => Ok(Map.toList(m) |> List.map(p -> match p { case (k, _) => k }))
            }
        )

    ///
    /// Selectors
    ///

    /// Reads from the column at the given (0-based) index.
    pub def column(idx: Int32, d: Decoder[a]): Decoder[a] =
        Decoder.Decoder((_, names, rowIdx, row) ->
            match d {
                case Decoder.Decoder(f) => f(Location.Column_(idx), names, rowIdx, row)
            }
        )

    /// Reads from the column whose header matches `name`. Requires
    /// `decodeCsv` to be called with `CustomFieldNames` or
    /// `FieldNamesFromFirstRow`.
    pub def field(name: String, d: Decoder[a]): Decoder[a] =
        Decoder.Decoder((_, names, rowIdx, row) ->
            match d {
                case Decoder.Decoder(f) => f(Location.Field_(name), names, rowIdx, row)
            }
        )

    /// Like `column`, but yields `None` (rather than failing) when the
    /// row is shorter than `idx + 1`.
    pub def optionalColumn(idx: Int32, d: Decoder[a]): Decoder[Option[a]] =
        Decoder.Decoder((_, names, rowIdx, row) ->
            if (idx >= List.length(row)) Ok(None)
            else
                match d {
                    case Decoder.Decoder(f) =>
                        match f(Location.Column_(idx), names, rowIdx, row) {
                            case Ok(x)   => Ok(Some(x))
                            case Err(es) => Err(es)
                        }
                }
        )

    /// Like `field`, but yields `None` (rather than failing) when the
    /// header `name` is not in the resolved field names. Still fails
    /// if no field names were resolved at all.
    pub def optionalField(name: String, d: Decoder[a]): Decoder[Option[a]] =
        Decoder.Decoder((_, names, rowIdx, row) ->
            match names#fieldNames {
                case None    => Err(DecodingError.NoFieldNamesProvided :: Nil)
                case Some(m) =>
                    if (Map.memberOf(name, m))
                        match d {
                            case Decoder.Decoder(f) =>
                                match f(Location.Field_(name), names, rowIdx, row) {
                                    case Ok(x)   => Ok(Some(x))
                                    case Err(es) => Err(es)
                                }
                        }
                    else Ok(None)
            }
        )

    ///
    /// Combinators
    ///

    /// Lifts a pure value into a decoder that always succeeds with it.
    pub def succeed(x: a): Decoder[a] =
        Decoder.Decoder((_, _, _, _) -> Ok(x))

    /// A decoder that always fails with `Problem.Failure(msg)`.
    pub def fail(msg: String): Decoder[a] =
        Decoder.Decoder((loc, names, rowIdx, _) ->
            Err(fieldErr(rowIdx, locToColumn(loc, names), Problem.Failure(msg)))
        )

    /// `succeed` specialised for the common pipeline pattern.
    /// `intoRecord f |> pipeline d1 |> pipeline d2` builds a record by
    /// threading `f` through each piped decoder. (Named `intoRecord`
    /// rather than `into` because `into` is a Flix keyword.)
    pub def intoRecord(f: a -> b): Decoder[a -> b] = succeed(f)

    /// Companion to `into`: applies the function carried by the right
    /// decoder to the value produced by the left decoder.
    pub def pipeline(d: Decoder[a], df: Decoder[a -> b]): Decoder[b] =
        map2((g, x) -> g(x), df, d)

    /// Maps the result of a successful decoder.
    pub def map(f: a -> b, d: Decoder[a]): Decoder[b] =
        Decoder.Decoder((loc, names, rowIdx, row) ->
            match d {
                case Decoder.Decoder(g) =>
                    match g(loc, names, rowIdx, row) {
                        case Ok(x)   => Ok(f(x))
                        case Err(es) => Err(es)
                    }
            }
        )

    /// Combines two decoders. Both run, and any errors are accumulated.
    pub def map2(f: (a, b) -> c, da: Decoder[a], db: Decoder[b]): Decoder[c] =
        Decoder.Decoder((loc, names, rowIdx, row) ->
            match (da, db) {
                case (Decoder.Decoder(fa), Decoder.Decoder(fb)) =>
                    let ra = fa(loc, names, rowIdx, row);
                    let rb = fb(loc, names, rowIdx, row);
                    match (ra, rb) {
                        case (Ok(a), Ok(b))     => Ok(f(a, b))
                        case (Err(ea), Err(eb)) => Err(List.append(ea, eb))
                        case (Err(ea), _)       => Err(ea)
                        case (_, Err(eb))       => Err(eb)
                    }
            }
        )

    /// Three-decoder lift, accumulating errors across all three.
    pub def map3(f: (a, b, c) -> d, da: Decoder[a], db: Decoder[b], dc: Decoder[c]): Decoder[d] =
        map2((pair, z) -> match pair { case (x, y) => f(x, y, z) },
             map2((x, y) -> (x, y), da, db),
             dc)

    /// Tries the first decoder, then each fallback in order. If all
    /// fail, the errors are bundled into a single `OneOfDecodingError`
    /// for that row.
    pub def oneOf(first: Decoder[a], rest: List[Decoder[a]]): Decoder[a] =
        Decoder.Decoder((loc, names, rowIdx, row) ->
            oneOfHelper(first :: rest, loc, names, rowIdx, row, Nil)
        )

    def oneOfHelper(
        decoders: List[Decoder[a]],
        loc: Location,
        names: ResolvedNames,
        rowIdx: Int32,
        row: List[String],
        accErrs: List[DecodingError]
    ): Result[List[DecodingError], a] =
        match decoders {
            case Nil =>
                Err(DecodingError.OneOfDecodingError(rowIdx, List.reverse(accErrs)) :: Nil)
            case d :: more =>
                match d {
                    case Decoder.Decoder(f) =>
                        match f(loc, names, rowIdx, row) {
                            case Ok(x)   => Ok(x)
                            case Err(es) =>
                                oneOfHelper(more, loc, names, rowIdx, row, prependAll(es, accErrs))
                        }
                }
        }

    def prependAll(xs: List[a], acc: List[a]): List[a] =
        match xs {
            case Nil      => acc
            case x :: rest => prependAll(rest, x :: acc)
        }

    /// Sequences a value-dependent decoder after another. Errors from
    /// the first decoder short-circuit the second.
    pub def andThen(f: a -> Decoder[b], d: Decoder[a]): Decoder[b] =
        Decoder.Decoder((loc, names, rowIdx, row) ->
            match d {
                case Decoder.Decoder(g) =>
                    match g(loc, names, rowIdx, row) {
                        case Err(es) => Err(es)
                        case Ok(x) =>
                            match f(x) {
                                case Decoder.Decoder(h) => h(loc, names, rowIdx, row)
                            }
                    }
            }
        )

    /// Lifts a `Result[String, a]` into a decoder. Useful when reusing
    /// a parser that already returns Result.
    pub def fromResult(r: Result[String, a]): Decoder[a] =
        match r {
            case Ok(x)    => succeed(x)
            case Err(msg) => fail(msg)
        }

    /// Lifts a `Option[a]` into a decoder, failing with `msg` on `None`.
    pub def fromMaybe(msg: String, m: Option[a]): Decoder[a] =
        match m {
            case Some(x) => succeed(x)
            case None    => fail(msg)
        }

    ///
    /// Entry points
    ///

    /// Decodes a CSV string with comma as the field separator.
    pub def decodeCsv(names: FieldNames, d: Decoder[a], src: String): Result[Error, List[a]] =
        decodeCustom({fieldSeparator = ','}, names, d, src)

    /// Decodes a CSV string with a custom field separator.
    pub def decodeCustom(
        opts: {fieldSeparator = Char},
        names: FieldNames,
        d: Decoder[a],
        src: String
    ): Result[Error, List[a]] =
        match Parser.parse(opts, src) {
            case Err(p) => Err(Error.ParsingError(p))
            case Ok(rows) =>
                match resolveFieldNames(names, rows) {
                    case Err(e) => Err(e)
                    case Ok(pair) =>
                        match pair {
                            case (resolved, dataRows) => decodeRows(d, resolved, dataRows)
                        }
                }
        }

    /// Renders an `Error` into a human-readable, multi-line string.
    pub def errorToString(e: Error): String =
        match e {
            case Error.ParsingError(p)        => parseProblemToString(p)
            case Error.NoFieldNamesOnFirstRow => "Cannot decode the CSV with field names because the first row was missing."
            case Error.DecodingErrors(errs)   =>
                errs |> List.map(decodingErrorToString) |> List.join("\n")
        }

    ///
    /// Internals: error helpers
    ///

    def fieldErr(rowIdx: Int32, col: Column, problem: Problem): List[DecodingError] =
        DecodingError.FieldDecodingError(rowIdx, col, problem) :: Nil

    def locToColumn(loc: Location, names: ResolvedNames): Column =
        match loc {
            case Location.OnlyColumn_ => Column.OnlyColumn
            case Location.Column_(i)  => Column.Column(i)
            case Location.Field_(n)   =>
                match names#fieldNames {
                    case None    => Column.Field(n, None)
                    case Some(m) => Column.Field(n, Map.get(n, m))
                }
        }

    def parseProblemToString(p: Parser.ParseProblem): String =
        match p {
            case Parser.ParseProblem.SourceEndedWithoutClosingQuote(pos) =>
                "There was a problem parsing the CSV: source ended without closing quote at position ${pos}."
            case Parser.ParseProblem.AdditionalCharactersAfterClosingQuote(pos) =>
                "There was a problem parsing the CSV: additional characters after closing quote at position ${pos}."
        }

    def decodingErrorToString(e: DecodingError): String =
        match e {
            case DecodingError.FieldDecodingError(r, c, p) =>
                "There was a problem on row ${r}, in ${columnToString(c)}: ${problemToString(p)}"
            case DecodingError.OneOfDecodingError(r, sub) =>
                "Row ${r} could not be decoded by any of the alternatives: " +
                    (sub |> List.map(decodingErrorToString) |> List.join("; "))
            case DecodingError.FieldNotProvided(name) =>
                "The field \"${name}\" was not provided."
            case DecodingError.NoFieldNamesProvided =>
                "Cannot decode by field name because no field names were provided."
        }

    def columnToString(c: Column): String =
        match c {
            case Column.Column(i)   => "column ${i}"
            case Column.Field(n, _) => "the column named \"${n}\""
            case Column.OnlyColumn  => "the only column"
        }

    def problemToString(p: Problem): String =
        match p {
            case Problem.ColumnNotFound(i)    => "column ${i} was not found"
            case Problem.FieldNotFound(n)     => "the field \"${n}\" was not found"
            case Problem.ExpectedOneColumn(i) => "expected exactly one column, but the row had ${i}"
            case Problem.ExpectedInt(s)       => "expected an int but got \"${s}\""
            case Problem.ExpectedFloat(s)     => "expected a float but got \"${s}\""
            case Problem.Failure(msg)         => msg
        }

    ///
    /// Internals: field lookup
    ///

    def getField(loc: Location, names: ResolvedNames, rowIdx: Int32, row: List[String]): Result[List[DecodingError], String] =
        match loc {
            case Location.OnlyColumn_ =>
                match row {
                    case x :: Nil => Ok(x)
                    case _        =>
                        Err(fieldErr(rowIdx, Column.OnlyColumn, Problem.ExpectedOneColumn(List.length(row))))
                }
            case Location.Column_(idx) =>
                match List.nth(idx, row) {
                    case Some(s) => Ok(s)
                    case None    =>
                        Err(fieldErr(rowIdx, Column.Column(idx), Problem.ColumnNotFound(idx)))
                }
            case Location.Field_(name) =>
                match names#fieldNames {
                    case None    => Err(DecodingError.NoFieldNamesProvided :: Nil)
                    case Some(m) =>
                        match Map.get(name, m) {
                            case None      =>
                                Err(fieldErr(rowIdx, Column.Field(name, None), Problem.FieldNotFound(name)))
                            case Some(idx) =>
                                match List.nth(idx, row) {
                                    case Some(s) => Ok(s)
                                    case None    =>
                                        Err(fieldErr(rowIdx, Column.Field(name, Some(idx)), Problem.FieldNotFound(name)))
                                }
                        }
                }
        }

    ///
    /// Internals: header / row driver
    ///

    def resolveFieldNames(
        names: FieldNames,
        rows: List[List[String]]
    ): Result[Error, (ResolvedNames, List[List[String]])] =
        match names {
            case FieldNames.NoFieldNames =>
                Ok(({fieldNames = None}, rows))
            case FieldNames.CustomFieldNames(headers) =>
                Ok(({fieldNames = Some(headersToMap(headers))}, rows))
            case FieldNames.FieldNamesFromFirstRow =>
                match rows {
                    case Nil => Err(Error.NoFieldNamesOnFirstRow)
                    case headers :: rest =>
                        Ok(({fieldNames = Some(headersToMap(headers))}, rest))
                }
        }

    def headersToMap(headers: List[String]): Map[String, Int32] =
        let folded = List.foldLeft(
            (state, name) -> match state {
                case (i, m) => (i + 1, Map.insert(name, i, m))
            },
            (0, Map.empty()),
            headers
        );
        match folded { case (_, m) => m }

    def decodeRows(d: Decoder[a], names: ResolvedNames, rows: List[List[String]]): Result[Error, List[a]] =
        let folded = List.foldLeft(
            (state, row) -> match state {
                case (idx, Ok(acc)) =>
                    match d {
                        case Decoder.Decoder(f) =>
                            match f(Location.OnlyColumn_, names, idx, row) {
                                case Ok(x)   => (idx + 1, Ok(x :: acc))
                                case Err(es) => (idx + 1, Err(es))
                            }
                    }
                case (idx, Err(acc)) =>
                    match d {
                        case Decoder.Decoder(f) =>
                            match f(Location.OnlyColumn_, names, idx, row) {
                                case Ok(_)    => (idx + 1, Err(acc))
                                case Err(es)  => (idx + 1, Err(List.append(acc, es)))
                            }
                    }
            },
            (0, Ok(Nil)),
            rows
        );
        match folded {
            case (_, Ok(reversed)) => Ok(List.reverse(reversed))
            case (_, Err(es))      => Err(Error.DecodingErrors(es))
        }

}
