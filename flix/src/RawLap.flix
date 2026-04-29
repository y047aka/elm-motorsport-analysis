mod RawLap {

    use Util.Csv
    use Util.Duration
    use Util.HourClock
    use Util.HourClock.Hour
    use Util.Json
    use Util.Json.JsonValue.{JsonObject, JsonString, JsonInt, JsonFloat, JsonArray}

    /// セクターセル: 成功時は Ok(ms)、空欄/未パース時は Err(raw)。
    /// Err は元 CSV 文字列を保持し、JSON 出力で round-trip する。
    pub type alias Sector = Result[String, Int32]

    /// 時刻セル: 成功時は Ok(Hour)、空欄/未パース時は Err(raw)。
    /// Err は元 CSV 文字列を保持し、JSON 出力で round-trip する。
    pub type alias HourCell = Result[String, Hour]

    pub type alias RawLap = {
        carNumber = String,
        driverNumber = Int32,
        lapNumber = Int32,
        lapTime = String,
        lapImprovement = Int32,
        crossingFinishLineInPit = String,
        s1 = Sector,
        s1Improvement = Int32,
        s2 = Sector,
        s2Improvement = Int32,
        s3 = Sector,
        s3Improvement = Int32,
        kph = String,
        elapsed = String,
        hour = HourCell,
        topSpeed = String,
        driverName = String,
        pitTime = String,
        class = String,
        group = String,
        team = String,
        manufacturer = String
    }

    pub def fromCsvRow(row: Csv.CsvRow): Option[RawLap] =
        forM(
            carNumber               <- List.nth(0, row);
            driverNumberStr         <- List.nth(1, row);
            lapNumberStr            <- List.nth(2, row);
            lapTime                 <- List.nth(3, row);
            lapImprovementStr       <- List.nth(4, row);
            crossingFinishLineInPit <- List.nth(5, row);
            s1                      <- List.nth(6, row);
            s1ImprovementStr        <- List.nth(7, row);
            s2                      <- List.nth(8, row);
            s2ImprovementStr        <- List.nth(9, row);
            s3                      <- List.nth(10, row);
            s3ImprovementStr        <- List.nth(11, row);
            kph                     <- List.nth(12, row);
            elapsed                 <- List.nth(13, row);
            hour                    <- List.nth(14, row);
            topSpeed                <- List.nth(18, row);
            driverName              <- List.nth(19, row);
            pitTime                 <- List.nth(20, row);
            class                   <- List.nth(21, row);
            group                   <- List.nth(22, row);
            team                    <- List.nth(23, row);
            manufacturer            <- List.nth(24, row)
        ) yield {
            carNumber               = carNumber,
            driverNumber            = parseIntOrZero(driverNumberStr),
            lapNumber               = parseIntOrZero(lapNumberStr),
            lapTime                 = Duration.normalize(lapTime),
            lapImprovement          = parseIntOrZero(lapImprovementStr),
            crossingFinishLineInPit = crossingFinishLineInPit,
            s1                      = parseSector(s1),
            s1Improvement           = parseIntOrZero(s1ImprovementStr),
            s2                      = parseSector(s2),
            s2Improvement           = parseIntOrZero(s2ImprovementStr),
            s3                      = parseSector(s3),
            s3Improvement           = parseIntOrZero(s3ImprovementStr),
            kph                     = kph,
            elapsed                 = Duration.normalize(elapsed),
            hour                    = HourClock.parse(hour),
            topSpeed                = stripTrailingDotZero(topSpeed),
            driverName              = driverName,
            pitTime                 = Duration.normalize(pitTime),
            class                   = class,
            group                   = group,
            team                    = team,
            manufacturer            = manufacturer
        }

    pub def fromCsvRows(rows: List[Csv.CsvRow]): List[RawLap] =
        rows |> List.filterMap(fromCsvRow)

    pub def toJson(rawLap: RawLap): Json.JsonValue =
        JsonObject(
            ("carNumber",               JsonString(rawLap#carNumber)) ::
            ("driverNumber",            JsonInt(rawLap#driverNumber)) ::
            ("lapNumber",               JsonInt(rawLap#lapNumber)) ::
            ("lapTime",                 JsonString(rawLap#lapTime)) ::
            ("lapImprovement",          JsonInt(rawLap#lapImprovement)) ::
            ("crossingFinishLineInPit", JsonString(rawLap#crossingFinishLineInPit)) ::
            ("s1",                      sectorJson(rawLap#s1)) ::
            ("s1Improvement",           JsonInt(rawLap#s1Improvement)) ::
            ("s2",                      sectorJson(rawLap#s2)) ::
            ("s2Improvement",           JsonInt(rawLap#s2Improvement)) ::
            ("s3",                      sectorJson(rawLap#s3)) ::
            ("s3Improvement",           JsonInt(rawLap#s3Improvement)) ::
            ("kph",                     kphValue(rawLap#kph)) ::
            ("elapsed",                 JsonString(rawLap#elapsed)) ::
            ("hour",                    hourJson(rawLap#hour)) ::
            ("topSpeed",                JsonString(rawLap#topSpeed)) ::
            ("driverName",              JsonString(rawLap#driverName)) ::
            ("pitTime",                 JsonString(rawLap#pitTime)) ::
            ("class",                   JsonString(rawLap#class)) ::
            ("group",                   JsonString(rawLap#group)) ::
            ("team",                    JsonString(rawLap#team)) ::
            ("manufacturer",            JsonString(rawLap#manufacturer)) ::
            Nil
        )

    pub def toJsonArray(rawLaps: List[RawLap]): Json.JsonValue =
        JsonArray(List.map(toJson, rawLaps))

    /// CSV のセクターセルを Sector(Result) に変換。
    /// 空欄や非数値はそのまま Err(raw) として保持し、JSON 出力で原文を round-trip。
    def parseSector(raw: String): Sector =
        match Duration.toMillis(raw) {
            case Some(ms) => Ok(ms)
            case None     => Err(raw)
        }

    /// Sector を JSON 出力する。Ok は Duration.format で正規化、Err は raw のまま。
    /// 結果は変更前 (Duration.normalize 経由の文字列) と byte-identical になる。
    def sectorJson(s: Sector): Json.JsonValue =
        match s {
            case Ok(ms)   => JsonString(Duration.format(ms))
            case Err(raw) => JsonString(raw)
        }

    /// HourCell を JSON 出力する。Ok は HourClock.format (HH:MM:SS.mmm) で
    /// 正規化、Err は raw のまま。WEC CSV はゼロパディング 2 桁時を採用しており、
    /// 結果は変更前(hour 列をそのまま JSON 出力)と byte-identical。
    def hourJson(h: HourCell): Json.JsonValue =
        match h {
            case Ok(hour) => JsonString(HourClock.format(hour))
            case Err(raw) => JsonString(raw)
        }

    def stripTrailingDotZero(s: String): String =
        if (String.endsWith({suffix = ".0"}, s))
            String.dropRight(2, s)
        else
            s

    def kphValue(s: String): Json.JsonValue =
        let trimmed = stripTrailingDotZero(s);
        match Int32.parse(10, trimmed) {
            case Ok(n)  => JsonInt(n)
            case Err(_) =>
                match Float64.fromString(trimmed) {
                    case Some(f) => JsonFloat(f)
                    case None    => JsonString(s)
                }
        }

    def parseIntOrZero(s: String): Int32 =
        match Int32.parse(10, s) {
            case Ok(n)  => n
            case Err(_) => 0
        }

}
