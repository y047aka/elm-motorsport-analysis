mod RawLap {

    use Util.Csv.Decode
    use Util.Csv.Decode.Decoder
    use Util.Duration.Duration
    use Util.HourClock
    use Util.HourClock.Hour
    use Util.Json
    use Util.Json.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}

    /// Improvement flag observed in WEC LAP_IMPROVEMENT and S*_IMPROVEMENT
    /// columns. Semantics derived from empirical CSV analysis:
    ///   None        = slower than this driver's personal best
    ///   DriverBest  = this driver's PB, but another driver on the same
    ///                 car has already been faster (sector-only — never
    ///                 observed on LAP_IMPROVEMENT)
    ///   CarBest     = fastest across every driver of this car so far
    ///   OverallBest = fastest of every running car so far (at most once
    ///                 per race per column)
    pub enum Improvement with Eq {
        case None
        case DriverBest
        case CarBest
        case OverallBest
    }

    /// Race flag state at the finish line when each lap was completed.
    /// Observed values across all WEC CSV files:
    ///   Green            = GF  — normal racing conditions
    ///   SlowZone         = SF  — safety car or local slow zone active
    ///   FullCourseYellow = FCY — full-course yellow, no overtaking
    ///   Red              = RF  — race suspended
    ///   Finish           = FF  — chequered flag (race end)
    pub enum Flag with Eq {
        case Green
        case SlowZone
        case FullCourseYellow
        case Red
        case Finish
    }

    /// Per-sector data parsed from the four CSV columns describing one
    /// sector (S/S_LARGE/S_SECONDS/S_IMPROVEMENT). The three time columns
    /// are cross-checked at decode time but only the canonical value is
    /// retained.
    pub type alias RawSector = {
        value = Option[Duration],
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
        number = Int32,
        name = String
    }

    pub type alias RawLap = {
        car = RawCar,
        driver = RawDriver,
        lapNumber = Int32,
        lapTime = Duration,
        lapImprovement = Improvement,
        crossingFinishLineInPit = String,
        s1 = RawSector,
        s2 = RawSector,
        s3 = RawSector,
        kph = String,
        elapsed = Duration,
        hour = Hour,
        topSpeed = String,
        pitTime = Option[Duration],
        flagAtFl = Flag
    }

    /// Decoder for a WEC-format lap row. The CSV is semicolon-separated
    /// with a header row; columns are identified by name so ordering and
    /// extra columns (e.g. S*_LARGE) are ignored automatically. Blank or
    /// unparseable required cells (LAP_TIME, ELAPSED, HOUR, IMPROVEMENT)
    /// fail the decode immediately. Sector time cells are `None` when
    /// blank, `Some(d)` otherwise.
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
            |> Decode.pipeline(durationField("LAP_TIME"))
            |> Decode.pipeline(improvementField("LAP_IMPROVEMENT"))
            |> Decode.pipeline(stringField("CROSSING_FINISH_LINE_IN_PIT"))
            |> Decode.pipeline(sectorDecoder("S1", "S1_LARGE", "S1_SECONDS", "S1_IMPROVEMENT"))
            |> Decode.pipeline(sectorDecoder("S2", "S2_LARGE", "S2_SECONDS", "S2_IMPROVEMENT"))
            |> Decode.pipeline(sectorDecoder("S3", "S3_LARGE", "S3_SECONDS", "S3_IMPROVEMENT"))
            |> Decode.pipeline(numericStringField("KPH"))
            |> Decode.pipeline(durationField("ELAPSED"))
            |> Decode.pipeline(hourField("HOUR"))
            |> Decode.pipeline(numericOrBlankStringField("TOP_SPEED"))
            |> Decode.pipeline(optionalDurationField("PIT_TIME"))
            |> Decode.pipeline(flagField("FLAG_AT_FL"))

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
            number -> name ->
                {
                    number = number,
                    name = name
                }
        )
            |> Decode.pipeline(intField("DRIVER_NUMBER"))
            |> Decode.pipeline(stringField("DRIVER_NAME"))

    pub def toJson(rawLap: RawLap): Json.JsonValue =
        JsonObject(
            ("carNumber",               JsonString(rawLap#car#carNumber)) ::
            ("driverNumber",            JsonInt(rawLap#driver#number)) ::
            ("lapNumber",               JsonInt(rawLap#lapNumber)) ::
            ("lapTime",                 JsonString(Util.Duration.format(rawLap#lapTime))) ::
            ("lapImprovement",          JsonInt(improvementToInt(rawLap#lapImprovement))) ::
            ("crossingFinishLineInPit", JsonString(rawLap#crossingFinishLineInPit)) ::
            ("s1",                      optionalDurationJson(rawLap#s1#value)) ::
            ("s1Improvement",           JsonInt(improvementToInt(rawLap#s1#improvement))) ::
            ("s2",                      optionalDurationJson(rawLap#s2#value)) ::
            ("s2Improvement",           JsonInt(improvementToInt(rawLap#s2#improvement))) ::
            ("s3",                      optionalDurationJson(rawLap#s3#value)) ::
            ("s3Improvement",           JsonInt(improvementToInt(rawLap#s3#improvement))) ::
            ("kph",                     JsonString(rawLap#kph)) ::
            ("elapsed",                 JsonString(Util.Duration.format(rawLap#elapsed))) ::
            ("hour",                    JsonString(HourClock.format(rawLap#hour))) ::
            ("topSpeed",                JsonString(rawLap#topSpeed)) ::
            ("driverName",              JsonString(rawLap#driver#name)) ::
            ("pitTime",                 optionalDurationJson(rawLap#pitTime)) ::
            ("class",                   JsonString(rawLap#car#class)) ::
            ("group",                   JsonString(rawLap#car#group)) ::
            ("team",                    JsonString(rawLap#car#team)) ::
            ("manufacturer",            JsonString(rawLap#car#manufacturer)) ::
            ("flagAtFl",                JsonString(flagToString(rawLap#flagAtFl))) ::
            Nil
        )

    pub def toJsonArray(rawLaps: List[RawLap]): Json.JsonValue =
        JsonArray(List.map(toJson, rawLaps))

    def stringField(name: String): Decoder[String] =
        Decode.field(name, Decode.string())

    /// Accepts any value parseable as Float64 or blank; non-numeric
    /// non-blank input fails decode. Raw string preserved unchanged.
    def numericOrBlankStringField(name: String): Decoder[String] =
        Decode.oneOf(
            numericStringField(name),
            stringField(name) |> Decode.andThen(s ->
                if (s == "") Decode.succeed(s)
                else Decode.fail("${name}: expected numeric or blank but got \"${s}\""))
            :: Nil
        )

    /// Accepts any value parseable as Float64; fails decode on blank or
    /// non-numeric input. The raw string is preserved unchanged in RawLap.
    def numericStringField(name: String): Decoder[String] =
        stringField(name) |> Decode.andThen(s -> Decode.fromResult(parseNumericString(name, s)))

    def parseNumericString(name: String, s: String): Result[String, String] =
        match Float64.fromString(s) {
            case Some(_) => Ok(s)
            case None    => Err("${name}: expected numeric but got \"${s}\"")
        }

    def durationField(name: String): Decoder[Duration] =
        stringField(name) |> Decode.andThen(s -> Decode.fromResult(parseDuration(name, s)))

    /// Duration-formatted input → `Duration`. Blank or unparseable input fails the decode.
    def parseDuration(name: String, raw: String): Result[String, Duration] =
        match Util.Duration.fromString(raw) {
            case Some(d) => Ok(d)
            case None    => Err("${name}: expected duration but got \"${raw}\"")
        }

    def optionalDurationField(name: String): Decoder[Option[Duration]] =
        stringField(name) |> Decode.andThen(s -> Decode.fromResult(parseOptionalDuration(name, s)))

    /// Blank → `None`. Numeric input → `Some(d)`. Anything else fails the
    /// decode so unfamiliar formatting surfaces immediately.
    def parseOptionalDuration(name: String, raw: String): Result[String, Option[Duration]] =
        match Util.Duration.fromString(raw) {
            case Some(d)           => Ok(Some(d))
            case None if raw == "" => Ok(None)
            case None              => Err("${name}: expected duration but got \"${raw}\"")
        }

    def intField(name: String): Decoder[Int32] =
        Decode.field(name, Decode.int())

    def hourField(name: String): Decoder[Hour] =
        stringField(name) |> Decode.andThen(s ->
            Decode.fromResult(HourClock.parse(s)
                |> Result.mapErr(_ -> "${name}: expected H:MM:SS.mmm but got \"${s}\"")))

    def improvementField(name: String): Decoder[Improvement] =
        stringField(name) |> Decode.andThen(s -> Decode.fromResult(parseImprovement(name, s)))

    def parseImprovement(name: String, s: String): Result[String, Improvement] =
        match s {
            case "0" => Ok(Improvement.None)
            case "1" => Ok(Improvement.DriverBest)
            case "2" => Ok(Improvement.CarBest)
            case "3" => Ok(Improvement.OverallBest)
            case _   => Err("${name}: expected 0/1/2/3 but got \"${s}\"")
        }

    def flagField(name: String): Decoder[Flag] =
        stringField(name) |> Decode.andThen(s -> Decode.fromResult(parseFlag(name, s)))

    def parseFlag(name: String, s: String): Result[String, Flag] =
        match s {
            case "GF"  => Ok(Flag.Green)
            case "SF"  => Ok(Flag.SlowZone)
            case "FCY" => Ok(Flag.FullCourseYellow)
            case "FF"  => Ok(Flag.Finish)
            case "RF"  => Ok(Flag.Red)
            case _     => Err("${name}: expected GF/SF/FCY/FF/RF but got \"${s}\"")
        }

    def flagToString(flag: Flag): String =
        match flag {
            case Flag.Green           => "GF"
            case Flag.SlowZone        => "SF"
            case Flag.FullCourseYellow => "FCY"
            case Flag.Finish          => "FF"
            case Flag.Red             => "RF"
        }

    def improvementToInt(imp: Improvement): Int32 =
        match imp {
            case Improvement.None        => 0
            case Improvement.DriverBest  => 1
            case Improvement.CarBest     => 2
            case Improvement.OverallBest => 3
        }

    /// Asserts the invariant that `S`, `S_LARGE`, and `S_SECONDS` encode
    /// the same elapsed time, failing the decode otherwise so an
    /// unfamiliar CSV layout surfaces immediately. Only the canonical
    /// value (and improvement flag) survive into RawSector.
    def sectorDecoder(name: String, largeName: String, secondsName: String, improvementName: String): Decoder[RawSector] =
        Decode.intoRecord(
            value -> large -> seconds -> improvement ->
                (value, large, seconds, improvement)
        )
            |> Decode.pipeline(optionalDurationField(name))
            |> Decode.pipeline(optionalDurationField(largeName))
            |> Decode.pipeline(stringField(secondsName))
            |> Decode.pipeline(improvementField(improvementName))
            |> Decode.andThen(parts -> match parts {
                case (value, large, seconds, improvement) =>
                    Decode.fromResult(checkSectorConsistency(name, value, large, seconds, improvement))
            })

    /// Blank cells are skipped, so a row with all three blank is treated
    /// as consistent. Unparseable `S_SECONDS` fails the decode.
    def checkSectorConsistency(name: String, valueMs: Option[Duration], largeMs: Option[Duration], secondsRaw: String, improvement: Improvement): Result[String, RawSector] =
        match secondsToMillis(name, secondsRaw) {
            case Err(e)       => Err(e)
            case Ok(secondsMs) =>
                let observed = List.filterMap(x -> x, valueMs :: largeMs :: secondsMs :: Nil);
                match observed {
                    case Nil           => Ok({ value = valueMs, improvement = improvement })
                    case first :: rest =>
                        if (List.forAll(x -> x == first, rest))
                            Ok({ value = valueMs, improvement = improvement })
                        else
                            Err("${name}: value/large/seconds disagree (value=${valueMs}, large=${largeMs}, seconds=${secondsMs})")
                }
        }

    /// Blank → `None`. Numeric seconds → `Some(d)`. Anything else fails
    /// the decode so unfamiliar `S_SECONDS` formatting surfaces immediately.
    def secondsToMillis(name: String, raw: String): Result[String, Option[Duration]] =
        if (raw == "") Ok(None)
        else match Float64.fromString(raw) {
            case Some(f) => match Float64.tryToInt32(Float64.round(f * 1000.0)) {
                case Some(ms) => Ok(Some(Util.Duration.fromMillis(ms)))
                case None     => Err("${name}: seconds out of range \"${raw}\"")
            }
            case None => Err("${name}: expected seconds but got \"${raw}\"")
        }


    /// Renders an `Option[Duration]` as JSON: `Some(d)` → formatted string,
    /// `None` → empty string.
    def optionalDurationJson(d: Option[Duration]): Json.JsonValue =
        match d {
            case Some(ms) => JsonString(Util.Duration.format(ms))
            case None     => JsonString("")
        }


}
