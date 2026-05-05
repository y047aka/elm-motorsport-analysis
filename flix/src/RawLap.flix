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

    /// Per-sector data bundling the four CSV columns describing one
    /// sector (S1/S2/S3): the parsed time, the long-form duplicate, the
    /// raw seconds-only column, and the improvement flag.
    pub type alias RawSector = {
        value = Sector,
        large = Sector,
        seconds = String,
        improvement = Int32
    }

    /// Car identity fields. These are constant across every lap of a
    /// given car, so it's natural to group them rather than repeating
    /// five flat fields on each `RawLap`.
    pub type alias RawCar = {
        carNumber = String,
        class = String,
        group = String,
        team = String,
        manufacturer = String
    }

    pub type alias RawLap = {
        car = RawCar,
        driverNumber = Int32,
        lapNumber = Int32,
        lapTime = String,
        lapImprovement = Int32,
        crossingFinishLineInPit = String,
        s1 = RawSector,
        s2 = RawSector,
        s3 = RawSector,
        kph = String,
        elapsed = String,
        hour = HourCell,
        topSpeed = String,
        driverName = String,
        pitTime = String,
        flagAtFl = String
    }

    /// Decoder for a WEC-format lap row. The CSV is semicolon-separated
    /// with a header row; columns are identified by name so ordering and
    /// extra columns (e.g. S*_LARGE) are ignored automatically. Numeric
    /// columns whose raw text is empty or unparseable degrade to `0`.
    /// Sector cells round-trip the raw text on parse failure via
    /// `Sector = Result[String, Int32]`.
    pub def decoder(): Decoder[RawLap] =
        Decode.intoRecord(
            car -> driverNumber -> lapNumber -> lapTime -> lapImprovement ->
            crossingFinishLineInPit -> s1 -> s2 -> s3 -> kph -> elapsed -> hour ->
            topSpeed -> driverName -> pitTime -> flagAtFl ->
                {
                    car = car,
                    driverNumber = driverNumber,
                    lapNumber = lapNumber,
                    lapTime = lapTime,
                    lapImprovement = lapImprovement,
                    crossingFinishLineInPit = crossingFinishLineInPit,
                    s1 = s1,
                    s2 = s2,
                    s3 = s3,
                    kph = kph,
                    elapsed = elapsed,
                    hour = hour,
                    topSpeed = topSpeed,
                    driverName = driverName,
                    pitTime = pitTime,
                    flagAtFl = flagAtFl
                }
        )
            |> Decode.pipeline(carDecoder())
            |> Decode.pipeline(intField("DRIVER_NUMBER"))
            |> Decode.pipeline(intField("LAP_NUMBER"))
            |> Decode.pipeline(Decode.field("LAP_TIME", Decode.map(Duration.normalize, Decode.string())))
            |> Decode.pipeline(intField("LAP_IMPROVEMENT"))
            |> Decode.pipeline(stringField("CROSSING_FINISH_LINE_IN_PIT"))
            |> Decode.pipeline(sectorDecoder("S1", "S1_LARGE", "S1_SECONDS", "S1_IMPROVEMENT"))
            |> Decode.pipeline(sectorDecoder("S2", "S2_LARGE", "S2_SECONDS", "S2_IMPROVEMENT"))
            |> Decode.pipeline(sectorDecoder("S3", "S3_LARGE", "S3_SECONDS", "S3_IMPROVEMENT"))
            |> Decode.pipeline(stringField("KPH"))
            |> Decode.pipeline(Decode.field("ELAPSED", Decode.map(Duration.normalize, Decode.string())))
            |> Decode.pipeline(Decode.field("HOUR", Decode.map(HourClock.parse, Decode.string())))
            |> Decode.pipeline(Decode.field("TOP_SPEED", Decode.map(stripTrailingDotZero, Decode.string())))
            |> Decode.pipeline(stringField("DRIVER_NAME"))
            |> Decode.pipeline(Decode.field("PIT_TIME", Decode.map(Duration.normalize, Decode.string())))
            |> Decode.pipeline(stringField("FLAG_AT_FL"))

    /// Decoder for the five car-identity columns. Reads NUMBER, CLASS,
    /// GROUP, TEAM, and MANUFACTURER and assembles them into a RawCar.
    def carDecoder(): Decoder[RawCar] =
        Decode.intoRecord(
            carNumber -> class -> group -> team -> manufacturer ->
                {
                    carNumber = carNumber,
                    class = class,
                    group = group,
                    team = team,
                    manufacturer = manufacturer
                }
        )
            |> Decode.pipeline(stringField("NUMBER"))
            |> Decode.pipeline(stringField("CLASS"))
            |> Decode.pipeline(stringField("GROUP"))
            |> Decode.pipeline(stringField("TEAM"))
            |> Decode.pipeline(stringField("MANUFACTURER"))

    pub def toJson(rawLap: RawLap): Json.JsonValue =
        JsonObject(
            ("carNumber",               JsonString(rawLap#car#carNumber)) ::
            ("driverNumber",            JsonInt(rawLap#driverNumber)) ::
            ("lapNumber",               JsonInt(rawLap#lapNumber)) ::
            ("lapTime",                 JsonString(rawLap#lapTime)) ::
            ("lapImprovement",          JsonInt(rawLap#lapImprovement)) ::
            ("crossingFinishLineInPit", JsonString(rawLap#crossingFinishLineInPit)) ::
            ("s1",                      sectorJson(rawLap#s1#value)) ::
            ("s1Improvement",           JsonInt(rawLap#s1#improvement)) ::
            ("s2",                      sectorJson(rawLap#s2#value)) ::
            ("s2Improvement",           JsonInt(rawLap#s2#improvement)) ::
            ("s3",                      sectorJson(rawLap#s3#value)) ::
            ("s3Improvement",           JsonInt(rawLap#s3#improvement)) ::
            ("kph",                     kphValue(rawLap#kph)) ::
            ("elapsed",                 JsonString(rawLap#elapsed)) ::
            ("hour",                    hourJson(rawLap#hour)) ::
            ("topSpeed",                JsonString(rawLap#topSpeed)) ::
            ("driverName",              JsonString(rawLap#driverName)) ::
            ("pitTime",                 JsonString(rawLap#pitTime)) ::
            ("class",                   JsonString(rawLap#car#class)) ::
            ("group",                   JsonString(rawLap#car#group)) ::
            ("team",                    JsonString(rawLap#car#team)) ::
            ("manufacturer",            JsonString(rawLap#car#manufacturer)) ::
            ("flagAtFl",                JsonString(rawLap#flagAtFl)) ::
            Nil
        )

    pub def toJsonArray(rawLaps: List[RawLap]): Json.JsonValue =
        JsonArray(List.map(toJson, rawLaps))

    def stringField(name: String): Decoder[String] =
        Decode.field(name, Decode.string())

    def intField(name: String): Decoder[Int32] =
        Decode.field(name, Decode.int())

    /// Decoder for one sector's four CSV columns (value, large duplicate,
    /// raw seconds, improvement flag). Bundling them keeps the outer
    /// pipeline aligned with logical sector grouping rather than the
    /// scattered CSV column order.
    ///
    /// Also asserts the data-format invariant: `value`, `large`, and
    /// `seconds` are three encodings of the same elapsed time. The
    /// decoder fails if the parseable representations disagree, so a
    /// surprising CSV layout surfaces immediately rather than silently
    /// corrupting downstream JSON.
    def sectorDecoder(name: String, largeName: String, secondsName: String, improvementName: String): Decoder[RawSector] =
        Decode.intoRecord(
            value -> large -> seconds -> improvement ->
                {
                    value = value,
                    large = large,
                    seconds = seconds,
                    improvement = improvement
                }
        )
            |> Decode.pipeline(Decode.field(name, Decode.map(parseSector, Decode.string())))
            |> Decode.pipeline(Decode.field(largeName, Decode.map(parseSector, Decode.string())))
            |> Decode.pipeline(stringField(secondsName))
            |> Decode.pipeline(intField(improvementName))
            |> Decode.andThen(sector -> match checkSectorConsistency(name, sector) {
                case Ok(())   => Decode.succeed(sector)
                case Err(msg) => Decode.fail(msg)
            })

    /// Verify the per-sector triple agrees. Each parseable representation
    /// is reduced to milliseconds; if two or more are present and any
    /// disagree, returns Err with a diagnostic. Blank/unparseable cells
    /// are skipped (they round-trip via the Err side of `Sector`).
    def checkSectorConsistency(name: String, s: RawSector): Result[String, Unit] =
        let valueMs   = Result.toOption(s#value);
        let largeMs   = Result.toOption(s#large);
        let secondsMs = secondsToMillis(s#seconds);
        let observed  = List.filterMap(x -> x, valueMs :: largeMs :: secondsMs :: Nil);
        match observed {
            case Nil           => Ok(())
            case first :: rest =>
                if (List.forAll(x -> x == first, rest))
                    Ok(())
                else
                    Err("${name}: value/large/seconds disagree (value=${valueMs}, large=${largeMs}, seconds=${secondsMs})")
        }

    /// Parse the `S*_SECONDS` raw text (e.g. `"41.805"`) as milliseconds.
    /// Returns `None` for blank or non-numeric input.
    def secondsToMillis(raw: String): Option[Int32] =
        if (raw == "") None
        else match Float64.fromString(raw) {
            case Some(f) => Float64.tryToInt32(Float64.round(f * 1000.0))
            case None    => None
        }

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
