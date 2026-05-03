mod RawLap {

    use Util.Csv.Decode
    use Util.Csv.Decode.Decoder
    use Util.Duration
    use Util.HourClock
    use Util.HourClock.Hour
    use Util.Json
    use Util.Json.JsonValue.{JsonObject, JsonString, JsonInt, JsonFloat, JsonArray}

    /// Sector cell: `Ok(ms)` on success, `Err(raw)` for blank or
    /// unparseable input. Err preserves the original CSV string so JSON
    /// output round-trips it verbatim.
    pub type alias Sector = Result[String, Int32]

    /// Hour-of-day cell: `Ok(Hour)` on success, `Err(raw)` otherwise.
    /// Err preserves the original CSV string so JSON output round-trips it.
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

    /// Decoder for a WEC-format lap row. The CSV is semicolon-separated
    /// and columns 15-17 (S*_LARGE) are skipped. Numeric columns whose
    /// raw text is empty or unparseable degrade to `0` rather than
    /// failing the whole row, matching the legacy `parseIntOrZero`
    /// behaviour. Sector cells round-trip the raw text on parse failure
    /// via `Sector = Result[String, Int32]`.
    pub def decoder(): Decoder[RawLap] =
        Decode.intoRecord(
            carNumber -> driverNumber -> lapNumber -> lapTime -> lapImprovement ->
            crossingFinishLineInPit -> s1 -> s1Improvement -> s2 -> s2Improvement ->
            s3 -> s3Improvement -> kph -> elapsed -> hour ->
            topSpeed -> driverName -> pitTime -> class -> group -> team -> manufacturer ->
                {
                    carNumber = carNumber,
                    driverNumber = driverNumber,
                    lapNumber = lapNumber,
                    lapTime = lapTime,
                    lapImprovement = lapImprovement,
                    crossingFinishLineInPit = crossingFinishLineInPit,
                    s1 = s1,
                    s1Improvement = s1Improvement,
                    s2 = s2,
                    s2Improvement = s2Improvement,
                    s3 = s3,
                    s3Improvement = s3Improvement,
                    kph = kph,
                    elapsed = elapsed,
                    hour = hour,
                    topSpeed = topSpeed,
                    driverName = driverName,
                    pitTime = pitTime,
                    class = class,
                    group = group,
                    team = team,
                    manufacturer = manufacturer
                }
        )
            |> Decode.pipeline(stringColumn(0))
            |> Decode.pipeline(intOrZero(1))
            |> Decode.pipeline(intOrZero(2))
            |> Decode.pipeline(mapColumn(3, Duration.normalize))
            |> Decode.pipeline(intOrZero(4))
            |> Decode.pipeline(stringColumn(5))
            |> Decode.pipeline(mapColumn(6, parseSector))
            |> Decode.pipeline(intOrZero(7))
            |> Decode.pipeline(mapColumn(8, parseSector))
            |> Decode.pipeline(intOrZero(9))
            |> Decode.pipeline(mapColumn(10, parseSector))
            |> Decode.pipeline(intOrZero(11))
            |> Decode.pipeline(stringColumn(12))
            |> Decode.pipeline(mapColumn(13, Duration.normalize))
            |> Decode.pipeline(mapColumn(14, HourClock.parse))
            |> Decode.pipeline(mapColumn(18, stripTrailingDotZero))
            |> Decode.pipeline(stringColumn(19))
            |> Decode.pipeline(mapColumn(20, Duration.normalize))
            |> Decode.pipeline(stringColumn(21))
            |> Decode.pipeline(stringColumn(22))
            |> Decode.pipeline(stringColumn(23))
            |> Decode.pipeline(stringColumn(24))

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

    /// Helper: a column read as a `String`.
    def stringColumn(idx: Int32): Decoder[String] =
        Decode.column(idx, Decode.string())

    /// Helper: a column read as a `String` then mapped through `f`.
    def mapColumn(idx: Int32, f: String -> a): Decoder[a] =
        stringColumn(idx) |> Decode.map(f)

    /// Helper: a column parsed as `Int32`, falling back to `0` when
    /// the raw cell is empty or unparseable.
    def intOrZero(idx: Int32): Decoder[Int32] =
        stringColumn(idx) |> Decode.map(s ->
            match Int32.parse(10, s) {
                case Ok(n)  => n
                case Err(_) => 0
            }
        )

    /// Parses a CSV sector cell into a Sector. Blank or non-numeric inputs
    /// are kept as `Err(raw)` so the original text can round-trip to JSON.
    def parseSector(raw: String): Sector =
        match Duration.toMillis(raw) {
            case Some(ms) => Ok(ms)
            case None     => Err(raw)
        }

    /// Renders a Sector as JSON. Ok is normalized through Duration.format,
    /// Err is emitted verbatim. The output is byte-identical with the
    /// pre-refactor result (which went through Duration.normalize).
    def sectorJson(s: Sector): Json.JsonValue =
        match s {
            case Ok(ms)   => JsonString(Duration.format(ms))
            case Err(raw) => JsonString(raw)
        }

    /// Renders an HourCell as JSON. Ok is normalized through HourClock.format
    /// (`HH:MM:SS.mmm`), Err is emitted verbatim. WEC CSVs use zero-padded
    /// two-digit hours, so the output is byte-identical with the
    /// pre-refactor result (which echoed the hour cell directly).
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

}
