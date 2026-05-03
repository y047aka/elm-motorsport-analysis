/// RFC 4180-style CSV parser.
///
/// Faithful port of the parser used by BrianHicks/elm-csv (see
/// `src/Csv/Parser.elm` in that repository). Supports quoted fields,
/// `""` as an escaped double quote, and both `\n` and `\r\n` line
/// endings. Custom field separators are supported via the
/// `fieldSeparator` record label.
mod Util.Csv.Parser {

    pub enum ParseProblem with Eq, ToString {
        case SourceEndedWithoutClosingQuote(Int32)
        case AdditionalCharactersAfterClosingQuote(Int32)
    }

    /// Parses a complete CSV source string into a list of rows.
    ///
    /// A trailing newline does not produce an extra empty row. An
    /// empty input returns `Ok(Nil)`.
    pub def parse(opts: {fieldSeparator = Char}, src: String): Result[ParseProblem, List[List[String]]] =
        stepInField(opts#fieldSeparator, String.toList(src), 0, Nil, Nil, Nil, false)

    /// Top-level / inside-an-unquoted-field state.
    /// `rowStarted` is true once any character (including a separator)
    /// has been consumed on the current row. It guards the "no trailing
    /// empty row at EOF" rule.
    def stepInField(
        sep: Char,
        chars: List[Char],
        pos: Int32,
        fieldRev: List[Char],
        rowRev: List[String],
        rowsRev: List[List[String]],
        rowStarted: Bool
    ): Result[ParseProblem, List[List[String]]] =
        match chars {
            case Nil =>
                if (rowStarted)
                    let row = finishRow(fieldRev, rowRev);
                    Ok(List.reverse(row :: rowsRev))
                else
                    Ok(List.reverse(rowsRev))
            case c :: rest =>
                if (c == '"' and List.isEmpty(fieldRev))
                    // Quote may only open a field at its very start.
                    stepInQuoted(sep, rest, pos + 1, Nil, rowRev, rowsRev)
                else if (c == sep)
                    let field = listToString(fieldRev);
                    stepInField(sep, rest, pos + 1, Nil, field :: rowRev, rowsRev, true)
                else if (c == '\n')
                    let row = finishRow(fieldRev, rowRev);
                    stepInField(sep, rest, pos + 1, Nil, Nil, row :: rowsRev, false)
                else if (c == '\r')
                    match rest {
                        case '\n' :: rest2 =>
                            let row = finishRow(fieldRev, rowRev);
                            stepInField(sep, rest2, pos + 2, Nil, Nil, row :: rowsRev, false)
                        case _ =>
                            // Bare CR: keep elm-csv's behaviour and treat as a row terminator.
                            let row = finishRow(fieldRev, rowRev);
                            stepInField(sep, rest, pos + 1, Nil, Nil, row :: rowsRev, false)
                    }
                else
                    stepInField(sep, rest, pos + 1, c :: fieldRev, rowRev, rowsRev, true)
        }

    /// Inside a `"..."` quoted field. `""` is unescaped to a single `"`.
    def stepInQuoted(
        sep: Char,
        chars: List[Char],
        pos: Int32,
        fieldRev: List[Char],
        rowRev: List[String],
        rowsRev: List[List[String]]
    ): Result[ParseProblem, List[List[String]]] =
        match chars {
            case Nil =>
                Err(ParseProblem.SourceEndedWithoutClosingQuote(pos))
            case '"' :: '"' :: rest =>
                stepInQuoted(sep, rest, pos + 2, '"' :: fieldRev, rowRev, rowsRev)
            case '"' :: rest =>
                stepAfterQuote(sep, rest, pos + 1, fieldRev, rowRev, rowsRev)
            case c :: rest =>
                stepInQuoted(sep, rest, pos + 1, c :: fieldRev, rowRev, rowsRev)
        }

    /// Just past a closing `"`. Only a separator, newline, or EOF is
    /// permitted. Anything else produces `AdditionalCharactersAfterClosingQuote`.
    def stepAfterQuote(
        sep: Char,
        chars: List[Char],
        pos: Int32,
        fieldRev: List[Char],
        rowRev: List[String],
        rowsRev: List[List[String]]
    ): Result[ParseProblem, List[List[String]]] =
        match chars {
            case Nil =>
                let row = finishRow(fieldRev, rowRev);
                Ok(List.reverse(row :: rowsRev))
            case c :: rest =>
                if (c == sep)
                    let field = listToString(fieldRev);
                    stepInField(sep, rest, pos + 1, Nil, field :: rowRev, rowsRev, true)
                else if (c == '\n')
                    let row = finishRow(fieldRev, rowRev);
                    stepInField(sep, rest, pos + 1, Nil, Nil, row :: rowsRev, false)
                else if (c == '\r')
                    match rest {
                        case '\n' :: rest2 =>
                            let row = finishRow(fieldRev, rowRev);
                            stepInField(sep, rest2, pos + 2, Nil, Nil, row :: rowsRev, false)
                        case _ =>
                            Err(ParseProblem.AdditionalCharactersAfterClosingQuote(pos))
                    }
                else
                    Err(ParseProblem.AdditionalCharactersAfterClosingQuote(pos))
        }

    /// Materialises the in-progress field and prepends it to the row.
    /// Returns the row in forward order.
    def finishRow(fieldRev: List[Char], rowRev: List[String]): List[String] =
        let field = listToString(fieldRev);
        List.reverse(field :: rowRev)

    /// Reverses a `List[Char]` and concatenates them into a `String`.
    /// Avoids quadratic `+` chains by collecting into a list first.
    def listToString(charsRev: List[Char]): String =
        charsRev
            |> List.reverse
            |> List.foldLeft((acc, c) -> acc + Char.toString(c), "")

}
