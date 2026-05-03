/// CSV parser modelled after BrianHicks/elm-csv's `Csv.Parser`.
/// Function names and call structure mirror the elm-csv 4.0.1
/// source so the two implementations can be reviewed side by side.
mod Util.Csv.Parser {

    pub enum Problem with Eq, ToString {
        case SourceEndedWithoutClosingQuote(Int32)
        case AdditionalCharactersAfterClosingQuote(Int32)
    }

    pub def parse(opts: {fieldSeparator = Char}, src: String): Result[Problem, List[List[String]]] =
        if (String.isEmpty(src))
            Ok(Nil)
        else if (opts#fieldSeparator == ',')
            parseComma(String.toList(src), Nil, Nil, Nil)
        else if (opts#fieldSeparator == ';')
            parseSemicolon(String.toList(src), Nil, Nil, Nil)
        else
            parseHelp(c -> c == opts#fieldSeparator, String.toList(src), Nil, Nil, Nil)

    def parseQuotedField(
        isFieldSep: Char -> Bool,
        fieldRev: List[Char],
        chars: List[Char]
    ): Result[Int32 -> Problem, (String, List[Char], Bool)] =
        match chars {
            case Nil =>
                Err(n -> Problem.SourceEndedWithoutClosingQuote(n))
            case '"' :: '"' :: rest =>
                parseQuotedField(isFieldSep, '"' :: fieldRev, rest)
            case '"' :: rest =>
                let value = listToString(fieldRev);
                match rest {
                    case Nil => Ok((value, Nil, false))
                    case c :: rest2 =>
                        if (isFieldSep(c))
                            Ok((value, rest2, false))
                        else if (c == '\n')
                            Ok((value, rest2, true))
                        else if (c == '\r')
                            match rest2 {
                                case '\n' :: rest3 => Ok((value, rest3, true))
                                case _ => Err(n -> Problem.AdditionalCharactersAfterClosingQuote(n))
                            }
                        else
                            Err(n -> Problem.AdditionalCharactersAfterClosingQuote(n))
                }
            case c :: rest =>
                parseQuotedField(isFieldSep, c :: fieldRev, rest)
        }

    def parseHelp(
        isFieldSep: Char -> Bool,
        chars: List[Char],
        fieldRev: List[Char],
        row: List[String],
        rows: List[List[String]]
    ): Result[Problem, List[List[String]]] =
        match chars {
            case Nil =>
                let finalField = listToString(fieldRev);
                if (finalField == "" and List.isEmpty(row))
                    Ok(List.reverse(rows))
                else
                    Ok(List.reverse(List.reverse(finalField :: row) :: rows))
            case c :: rest =>
                if (isFieldSep(c))
                    parseHelp(isFieldSep, rest, Nil, listToString(fieldRev) :: row, rows)
                else if (c == '\n')
                    parseHelp(isFieldSep, rest, Nil, Nil, List.reverse(listToString(fieldRev) :: row) :: rows)
                else if (c == '\r')
                    match rest {
                        case '\n' :: rest2 =>
                            parseHelp(isFieldSep, rest2, Nil, Nil, List.reverse(listToString(fieldRev) :: row) :: rows)
                        case _ =>
                            parseHelp(isFieldSep, rest, c :: fieldRev, row, rows)
                    }
                else if (c == '"')
                    match parseQuotedField(isFieldSep, Nil, rest) {
                        case Ok((value, remaining, rowEnded)) =>
                            if (rowEnded)
                                parseHelp(isFieldSep, remaining, Nil, Nil, List.reverse(value :: row) :: rows)
                            else
                                parseHelp(isFieldSep, remaining, Nil, value :: row, rows)
                        case Err(problem) =>
                            Err(problem(List.length(rows) + 1))
                    }
                else
                    parseHelp(isFieldSep, rest, c :: fieldRev, row, rows)
        }

    /// `parseComma` and `parseSemicolon` are specialised copies of
    /// `parseHelp` for the two most common CSV separators. In the
    /// original Elm source this duplication exists so the compiler
    /// emits literal `===` comparisons in the generated JavaScript.
    /// On the JVM that codegen rationale does not apply, but the
    /// duplication is kept here for parity with the original.
    def parseComma(
        chars: List[Char],
        fieldRev: List[Char],
        row: List[String],
        rows: List[List[String]]
    ): Result[Problem, List[List[String]]] =
        match chars {
            case Nil =>
                let finalField = listToString(fieldRev);
                if (finalField == "" and List.isEmpty(row))
                    Ok(List.reverse(rows))
                else
                    Ok(List.reverse(List.reverse(finalField :: row) :: rows))
            case c :: rest =>
                if (c == ',')
                    parseComma(rest, Nil, listToString(fieldRev) :: row, rows)
                else if (c == '\n')
                    parseComma(rest, Nil, Nil, List.reverse(listToString(fieldRev) :: row) :: rows)
                else if (c == '\r')
                    match rest {
                        case '\n' :: rest2 =>
                            parseComma(rest2, Nil, Nil, List.reverse(listToString(fieldRev) :: row) :: rows)
                        case _ =>
                            parseComma(rest, c :: fieldRev, row, rows)
                    }
                else if (c == '"')
                    match parseQuotedField(ch -> ch == ',', Nil, rest) {
                        case Ok((value, remaining, rowEnded)) =>
                            if (rowEnded)
                                parseComma(remaining, Nil, Nil, List.reverse(value :: row) :: rows)
                            else
                                parseComma(remaining, Nil, value :: row, rows)
                        case Err(problem) =>
                            Err(problem(List.length(rows) + 1))
                    }
                else
                    parseComma(rest, c :: fieldRev, row, rows)
        }

    def parseSemicolon(
        chars: List[Char],
        fieldRev: List[Char],
        row: List[String],
        rows: List[List[String]]
    ): Result[Problem, List[List[String]]] =
        match chars {
            case Nil =>
                let finalField = listToString(fieldRev);
                if (finalField == "" and List.isEmpty(row))
                    Ok(List.reverse(rows))
                else
                    Ok(List.reverse(List.reverse(finalField :: row) :: rows))
            case c :: rest =>
                if (c == ';')
                    parseSemicolon(rest, Nil, listToString(fieldRev) :: row, rows)
                else if (c == '\n')
                    parseSemicolon(rest, Nil, Nil, List.reverse(listToString(fieldRev) :: row) :: rows)
                else if (c == '\r')
                    match rest {
                        case '\n' :: rest2 =>
                            parseSemicolon(rest2, Nil, Nil, List.reverse(listToString(fieldRev) :: row) :: rows)
                        case _ =>
                            parseSemicolon(rest, c :: fieldRev, row, rows)
                    }
                else if (c == '"')
                    match parseQuotedField(ch -> ch == ';', Nil, rest) {
                        case Ok((value, remaining, rowEnded)) =>
                            if (rowEnded)
                                parseSemicolon(remaining, Nil, Nil, List.reverse(value :: row) :: rows)
                            else
                                parseSemicolon(remaining, Nil, value :: row, rows)
                        case Err(problem) =>
                            Err(problem(List.length(rows) + 1))
                    }
                else
                    parseSemicolon(rest, c :: fieldRev, row, rows)
        }

    /// `List[Char]` -> `String`. Flix-specific helper: the original
    /// Elm parser uses `String.slice` on the source instead of
    /// accumulating a buffer, so it has no equivalent.
    def listToString(charsRev: List[Char]): String =
        charsRev
            |> List.reverse
            |> List.foldLeft((acc, c) -> acc + Char.toString(c), "")

}
