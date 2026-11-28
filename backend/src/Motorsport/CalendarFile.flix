/// The calendar as a file: read once at startup, and it fails by naming the
/// key that is wrong rather than becoming a round drawn as a ring, or a card
/// linking to no file, silently.
pub mod Motorsport.CalendarFile {

    use Motorsport.Calendar.{Calendar, Round, Season}
    use Motorsport.Circuit.Circuit
    use Util.Files
    use Util.Json.Json

    /// The one path every stage reaches for when the run names none.
    pub def defaultPath(): String =
        "../data/wec/calendar.json"

    pub def read(path: String): Result[String, Calendar] \ IO =
        match Files.readLines(path) {
            case Err(e)    => Err("${e}")
            case Ok(lines) => parse(List.join("\n", lines))
        }

    pub def parse(text: String): Result[String, Calendar] =
        match Util.Json.parse(text) {
            case Err(e)   => Err("not JSON: ${e}")
            case Ok(json) => calendarOf(json)
        }

    def calendarOf(json: Json): Result[String, Calendar] =
        match seriesOf(json) {
            case Err(e)     => Err(e)
            case Ok(series) =>
                match seasonsOf(json) {
                    case Err(e)      => Err(e)
                    case Ok(seasons) =>
                        if (List.isEmpty(seasons))
                            Err("seasons: lists no seasons")
                        else
                            match duplicateSeasons(seasons) {
                                case Err(e)   => Err(e)
                                case Ok(())   => Ok({ series = series, seasons = seasons })
                            }
                }
        }

    def seriesOf(json: Json): Result[String, String] =
        match field("series", json) {
            case None            => Err("series: missing")
            case Some(Json.JString(s)) =>
                if (String.isEmpty(s)) Err("series: empty") else Ok(s)
            case Some(_)        => Err("series: not a string")
        }

    def seasonsOf(json: Json): Result[String, List[Season]] =
        match field("seasons", json) {
            case None                 => Err("seasons: missing")
            case Some(Json.JArray(v)) => traverseIndexed(Vector.toList(v), "seasons", season)
            case Some(_)              => Err("seasons: not an array")
        }

    def season(path: String, json: Json): Result[String, Season] =
        match yearOf(path, json) {
            case Err(e)   => Err(e)
            case Ok(year) => roundsOf(path, year, json)
        }

    def yearOf(path: String, json: Json): Result[String, Int32] =
        match field("season", json) {
            case None => Err("${path}: season: missing")
            case Some(Json.JNumber(n)) =>
                match BigDecimal.toPlainString(n) |> Int32.fromString {
                    case Some(year) if year > 0 => Ok(year)
                    case Some(year)             => Err("${path}: season: ${year} is not a year")
                    case None                   => Err("${path}: season: ${BigDecimal.toPlainString(n)} is not a year")
                }
            case Some(_) => Err("${path}: season: not a number")
        }

    def roundsOf(path: String, year: Int32, json: Json): Result[String, Season] =
        match field("rounds", json) {
            case None => Err("${path}: rounds: missing")
            case Some(Json.JArray(v)) =>
                match traverseIndexed(Vector.toList(v), "${path}.rounds", round) {
                    case Err(e)     => Err(e)
                    case Ok(rounds) =>
                        if (List.isEmpty(rounds))
                            Err("${path}: rounds: a season listed without a round is a card linking to no file")
                        else
                            match duplicateIds("${path}", rounds) {
                                case Err(e)   => Err(e)
                                case Ok(())   => Ok({ season = year, rounds = rounds })
                            }
                }
            case Some(_) => Err("${path}: rounds: not an array")
        }

    def round(path: String, json: Json): Result[String, Round] =
        match str(path, "id", json) {
            case Err(e)  => Err(e)
            case Ok(id)  =>
                match dateOf(path, json) {
                    case Err(e)  => Err(e)
                    case Ok(day) =>
                        match str(path, "name", json) {
                            case Err(e)   => Err(e)
                            case Ok(name) =>
                                match circuitOf(path, json) {
                                    case Err(e)      => Err(e)
                                    case Ok(circuit) =>
                                        Ok({ id = id, date = day, name = name, circuit = circuit })
                                }
                        }
                }
        }

    def str(path: String, key: String, json: Json): Result[String, String] =
        match field(key, json) {
            case None                  => Err("${path}: ${key}: missing")
            case Some(Json.JString(s)) =>
                if (String.isEmpty(s)) Err("${path}: ${key}: empty") else Ok(s)
            case Some(_)               => Err("${path}: ${key}: not a string")
        }

    /// The date is opaque everywhere it travels -- a column, a summary key, a
    /// card -- so this read is the one place its shape can be proved.
    def dateOf(path: String, json: Json): Result[String, String] =
        match str(path, "date", json) {
            case Err(e) => Err(e)
            case Ok(s)  =>
                if (isDate(s)) Ok(s) else Err("${path}.date: '${s}' is not YYYY-MM-DD")
        }

    def circuitOf(path: String, json: Json): Result[String, Option[Circuit]] =
        match field("circuit", json) {
            case None            => Ok(None)
            case Some(Json.JString(s)) =>
                match Circuit.fromJson(s) {
                    case None    => Err("${path}.circuit: '${s}' is no circuit either spelling knows")
                    case Some(c) => Ok(Some(c))
                }
            case Some(_)         => Err("${path}.circuit: not a string")
        }

    def field(name: String, json: Json): Option[Json] =
        match json {
            case Json.JObject(fields) => Map.get(name, fields)
            case _                    => None
        }

    def traverseIndexed(
        xs: List[Json],
        path: String,
        f: (String, Json) -> Result[String, a]
    ): Result[String, List[a]] =
        walk(xs, path, 0, f)

    def walk(
        xs: List[Json],
        path: String,
        i: Int32,
        f: (String, Json) -> Result[String, a]
    ): Result[String, List[a]] =
        match xs {
            case Nil => Ok(Nil)
            case x :: rest =>
                match f("${path}[${i}]", x) {
                    case Err(e) => Err(e)
                    case Ok(v)  =>
                        match walk(rest, path, i + 1, f) {
                            case Err(e) => Err(e)
                            case Ok(vs) => Ok(v :: vs)
                        }
                }
        }

    def duplicateSeasons(seasons: List[Season]): Result[String, Unit] =
        match seasons {
            case Nil      => Ok(())
            case s :: rest =>
                if (List.exists(o -> o#season == s#season, rest))
                    Err("season: ${s#season} listed twice")
                else
                    duplicateSeasons(rest)
        }

    def duplicateIds(path: String, rounds: List[Round]): Result[String, Unit] =
        match rounds {
            case Nil      => Ok(())
            case r :: rest =>
                if (List.exists(o -> o#id == r#id, rest))
                    Err("${path}: round '${r#id}' listed twice")
                else
                    duplicateIds(path, rest)
        }

    def isDate(s: String): Bool =
        match String.toList(s) {
            case d1 :: d2 :: d3 :: d4 :: '-' :: m1 :: m2 :: '-' :: y1 :: y2 :: Nil =>
                List.forAll(isDigit, d1 :: d2 :: d3 :: d4 :: m1 :: m2 :: y1 :: y2 :: Nil)
            case _ => false
        }

    def isDigit(c: Char): Bool =
        c >= '0' and c <= '9'

}
