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

    /// Improvement flag observed in WEC LAP_IMPROVEMENT and S*_IMPROVEMENT
    /// columns. Semantics derived from empirical CSV analysis:
    ///   None        = slower than this driver's personal best
    ///   DriverBest  = this driver's PB, but another driver on the same
    ///                 car has already been faster (sector-only — never
    ///                 observed on LAP_IMPROVEMENT)
    ///   CarBest     = fastest across every driver of this car so far
    ///   OverallBest = fastest of every running car so far (at most once
    ///                 per race per column)
    pub enum Improvement with Eq, ToString {
        case None
        case DriverBest
        case CarBest
        case OverallBest
    }

    /// Per-sector data bundling the four CSV columns describing one
    /// sector (S1/S2/S3): the parsed time, the long-form duplicate, the
    /// raw seconds-only column, and the improvement flag.
    pub type alias RawSector = {
        value = Sector,
        large = Sector,
        seconds = String,
        improvement = Improvement
    }

    pub type alias RawCar = {
        carNumber = String,
        class = String,
        group = String,
        team = String,
        manufacturer = String
    }

    pub type alias RawDriver = {
        driverNumber = Int32,
        driverName = String
    }

    pub type alias RawLap = {
        car = RawCar,
        driver = RawDriver,
        lapNumber = Int32,
        lapTime = String,
        lapImprovement = Improvement,
        crossingFinishLineInPit = String,
        s1 = RawSector,
        s2 = RawSector,
        s3 = RawSector,
        kph = String,
        elapsed = String,
        hour = HourCell,
        topSpeed = String,
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
            car -> driver -> lapNumber -> lapTime -> lapImprovement ->
            crossingFinishLineInPit -> s1 -> s2 -> s3 -> kph -> elapsed -> hour ->
            topSpeed -> pitTime -> flagAtFl ->
                {
                    car = car,
                    driver = driver,
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
                    pitTime = pitTime,
                    flagAtFl = flagAtFl
                }
        )
            |> Decode.pipeline(carDecoder())
            |> Decode.pipeline(driverDecoder())
            |> Decode.pipeline(intField("LAP_NUMBER"))
            |> Decode.pipeline(Decode.field("LAP_TIME", Decode.map(Duration.normalize, Decode.string())))
            |> Decode.pipeline(improvementField("LAP_IMPROVEMENT"))
            |> Decode.pipeline(stringField("CROSSING_FINISH_LINE_IN_PIT"))
            |> Decode.pipeline(sectorDecoder("S1", "S1_LARGE", "S1_SECONDS", "S1_IMPROVEMENT"))
            |> Decode.pipeline(sectorDecoder("S2", "S2_LARGE", "S2_SECONDS", "S2_IMPROVEMENT"))
            |> Decode.pipeline(sectorDecoder("S3", "S3_LARGE", "S3_SECONDS", "S3_IMPROVEMENT"))
            |> Decode.pipeline(stringField("KPH"))
            |> Decode.pipeline(Decode.field("ELAPSED", Decode.map(Duration.normalize, Decode.string())))
            |> Decode.pipeline(Decode.field("HOUR", Decode.map(HourClock.parse, Decode.string())))
            |> Decode.pipeline(Decode.field("TOP_SPEED", Decode.map(stripTrailingDotZero, Decode.string())))
            |> Decode.pipeline(Decode.field("PIT_TIME", Decode.map(Duration.normalize, Decode.string())))
            |> Decode.pipeline(stringField("FLAG_AT_FL"))

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

    def driverDecoder(): Decoder[RawDriver] =
        Decode.intoRecord(
            driverNumber -> driverName ->
                {
                    driverNumber = driverNumber,
                    driverName = driverName
                }
        )
            |> Decode.pipeline(intField("DRIVER_NUMBER"))
            |> Decode.pipeline(stringField("DRIVER_NAME"))

    pub def toJson(rawLap: RawLap): Json.JsonValue =
        JsonObject(
            ("carNumber",               JsonString(rawLap#car#carNumber)) ::
            ("driverNumber",            JsonInt(rawLap#driver#driverNumber)) ::
            ("lapNumber",               JsonInt(rawLap#lapNumber)) ::
            ("lapTime",                 JsonString(rawLap#lapTime)) ::
            ("lapImprovement",          JsonInt(improvementToInt(rawLap#lapImprovement))) ::
            ("crossingFinishLineInPit", JsonString(rawLap#crossingFinishLineInPit)) ::
            ("s1",                      sectorJson(rawLap#s1#value)) ::
            ("s1Improvement",           JsonInt(improvementToInt(rawLap#s1#improvement))) ::
            ("s2",                      sectorJson(rawLap#s2#value)) ::
            ("s2Improvement",           JsonInt(improvementToInt(rawLap#s2#improvement))) ::
            ("s3",                      sectorJson(rawLap#s3#value)) ::
            ("s3Improvement",           JsonInt(improvementToInt(rawLap#s3#improvement))) ::
            ("kph",                     kphValue(rawLap#kph)) ::
            ("elapsed",                 JsonString(rawLap#elapsed)) ::
            ("hour",                    hourJson(rawLap#hour)) ::
            ("topSpeed",                JsonString(rawLap#topSpeed)) ::
            ("driverName",              JsonString(rawLap#driver#driverName)) ::
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

    def improvementField(name: String): Decoder[Improvement] =
        stringField(name) |> Decode.andThen(s -> match s {
            case "0" => Decode.succeed(Improvement.None)
            case "1" => Decode.succeed(Improvement.DriverBest)
            case "2" => Decode.succeed(Improvement.CarBest)
            case "3" => Decode.succeed(Improvement.OverallBest)
            case _   => Decode.fail("${name}: expected 0/1/2/3 but got \"${s}\"")
        })

    def improvementToInt(imp: Improvement): Int32 =
        match imp {
            case Improvement.None        => 0
            case Improvement.DriverBest  => 1
            case Improvement.CarBest     => 2
            case Improvement.OverallBest => 3
        }

    /// Asserts the invariant that `S`, `S_LARGE`, and `S_SECONDS` encode
    /// the same elapsed time, failing the decode otherwise so an
    /// unfamiliar CSV layout surfaces immediately.
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
            |> Decode.pipeline(improvementField(improvementName))
            |> Decode.andThen(sector -> match checkSectorConsistency(name, sector) {
                case Ok(())   => Decode.succeed(sector)
                case Err(msg) => Decode.fail(msg)
            })

    /// Blank/unparseable cells are skipped, so a row with all three
    /// blank is treated as consistent.
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
