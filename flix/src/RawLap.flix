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
        s1Large = Sector,
        s2Large = Sector,
        s3Large = Sector,
        topSpeed = String,
        driverName = String,
        pitTime = String,
        class = String,
        group = String,
        team = String,
        manufacturer = String,
        flagAtFl = String,
        s1Seconds = String,
        s2Seconds = String,
        s3Seconds = String
    }

    /// Decoder for a WEC-format lap row. The CSV is semicolon-separated
    /// with a header row; columns are identified by name so ordering and
    /// extra columns (e.g. S*_LARGE) are ignored automatically. Numeric
    /// columns whose raw text is empty or unparseable degrade to `0`.
    /// Sector cells round-trip the raw text on parse failure via
    /// `Sector = Result[String, Int32]`.
    pub def decoder(): Decoder[RawLap] =
        Decode.intoRecord(
            carNumber -> driverNumber -> lapNumber -> lapTime -> lapImprovement ->
            crossingFinishLineInPit -> s1 -> s1Improvement -> s2 -> s2Improvement ->
            s3 -> s3Improvement -> kph -> elapsed -> hour ->
            s1Large -> s2Large -> s3Large ->
            topSpeed -> driverName -> pitTime -> class -> group -> team -> manufacturer ->
            flagAtFl -> s1Seconds -> s2Seconds -> s3Seconds ->
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
                    s1Large = s1Large,
                    s2Large = s2Large,
                    s3Large = s3Large,
                    topSpeed = topSpeed,
                    driverName = driverName,
                    pitTime = pitTime,
                    class = class,
                    group = group,
                    team = team,
                    manufacturer = manufacturer,
                    flagAtFl = flagAtFl,
                    s1Seconds = s1Seconds,
                    s2Seconds = s2Seconds,
                    s3Seconds = s3Seconds
                }
        )
            |> Decode.pipeline(stringField("NUMBER"))
            |> Decode.pipeline(intField("DRIVER_NUMBER"))
            |> Decode.pipeline(intField("LAP_NUMBER"))
            |> Decode.pipeline(Decode.field("LAP_TIME", Decode.map(Duration.normalize, Decode.string())))
            |> Decode.pipeline(intField("LAP_IMPROVEMENT"))
            |> Decode.pipeline(stringField("CROSSING_FINISH_LINE_IN_PIT"))
            |> Decode.pipeline(Decode.field("S1", Decode.map(parseSector, Decode.string())))
            |> Decode.pipeline(intField("S1_IMPROVEMENT"))
            |> Decode.pipeline(Decode.field("S2", Decode.map(parseSector, Decode.string())))
            |> Decode.pipeline(intField("S2_IMPROVEMENT"))
            |> Decode.pipeline(Decode.field("S3", Decode.map(parseSector, Decode.string())))
            |> Decode.pipeline(intField("S3_IMPROVEMENT"))
            |> Decode.pipeline(stringField("KPH"))
            |> Decode.pipeline(Decode.field("ELAPSED", Decode.map(Duration.normalize, Decode.string())))
            |> Decode.pipeline(Decode.field("HOUR", Decode.map(HourClock.parse, Decode.string())))
            |> Decode.pipeline(Decode.field("S1_LARGE", Decode.map(parseSector, Decode.string())))
            |> Decode.pipeline(Decode.field("S2_LARGE", Decode.map(parseSector, Decode.string())))
            |> Decode.pipeline(Decode.field("S3_LARGE", Decode.map(parseSector, Decode.string())))
            |> Decode.pipeline(Decode.field("TOP_SPEED", Decode.map(stripTrailingDotZero, Decode.string())))
            |> Decode.pipeline(stringField("DRIVER_NAME"))
            |> Decode.pipeline(Decode.field("PIT_TIME", Decode.map(Duration.normalize, Decode.string())))
            |> Decode.pipeline(stringField("CLASS"))
            |> Decode.pipeline(stringField("GROUP"))
            |> Decode.pipeline(stringField("TEAM"))
            |> Decode.pipeline(stringField("MANUFACTURER"))
            |> Decode.pipeline(stringField("FLAG_AT_FL"))
            |> Decode.pipeline(stringField("S1_SECONDS"))
            |> Decode.pipeline(stringField("S2_SECONDS"))
            |> Decode.pipeline(stringField("S3_SECONDS"))

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
            ("s1Large",                 sectorJson(rawLap#s1Large)) ::
            ("s2Large",                 sectorJson(rawLap#s2Large)) ::
            ("s3Large",                 sectorJson(rawLap#s3Large)) ::
            ("topSpeed",                JsonString(rawLap#topSpeed)) ::
            ("driverName",              JsonString(rawLap#driverName)) ::
            ("pitTime",                 JsonString(rawLap#pitTime)) ::
            ("class",                   JsonString(rawLap#class)) ::
            ("group",                   JsonString(rawLap#group)) ::
            ("team",                    JsonString(rawLap#team)) ::
            ("manufacturer",            JsonString(rawLap#manufacturer)) ::
            ("flagAtFl",                JsonString(rawLap#flagAtFl)) ::
            ("s1Seconds",               JsonString(rawLap#s1Seconds)) ::
            ("s2Seconds",               JsonString(rawLap#s2Seconds)) ::
            ("s3Seconds",               JsonString(rawLap#s3Seconds)) ::
            Nil
        )

    pub def toJsonArray(rawLaps: List[RawLap]): Json.JsonValue =
        JsonArray(List.map(toJson, rawLaps))

    def stringField(name: String): Decoder[String] =
        Decode.field(name, Decode.string())

    def intField(name: String): Decoder[Int32] =
        Decode.field(name, Decode.int())

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
