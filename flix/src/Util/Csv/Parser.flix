mod Util.Csv.Parser {

    pub enum ParseProblem with Eq, ToString {
        case SourceEndedWithoutClosingQuote(Int32)
        case AdditionalCharactersAfterClosingQuote(Int32)
    }

    pub def parse(opts: {fieldSeparator = Char}, src: String): Result[ParseProblem, List[List[String]]] =
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
    ): Result[Int32 -> ParseProblem, (String, List[Char], Bool)] =
        match chars {
            case Nil =>
                Err(n -> ParseProblem.SourceEndedWithoutClosingQuote(n))
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
                                case _ => Err(n -> ParseProblem.AdditionalCharactersAfterClosingQuote(n))
                            }
                        else
                            Err(n -> ParseProblem.AdditionalCharactersAfterClosingQuote(n))
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
    ): Result[ParseProblem, List[List[String]]] =
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

    def parseComma(
        chars: List[Char],
        fieldRev: List[Char],
        row: List[String],
        rows: List[List[String]]
    ): Result[ParseProblem, List[List[String]]] =
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
    ): Result[ParseProblem, List[List[String]]] =
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

    def listToString(charsRev: List[Char]): String =
        charsRev
            |> List.reverse
            |> List.foldLeft((acc, c) -> acc + Char.toString(c), "")

}
