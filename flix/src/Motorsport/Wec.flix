mod Motorsport.Wec {

    use Util.Csv.Decode
    use Util.Csv.Decode.Decoder
    use Util.Csv.Decode.Extra
    use Util.Duration.Duration
    use Util.HourClock
    use Util.HourClock.Hour
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId

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

    pub type alias RawSector = {
        value = Option[Duration],
        improvement = Improvement
    }

    /// One Le Mans mini-sector observation. `time` is the segment duration
    /// from the previous marker; `elapsed` is the cumulative time from the
    /// start of the lap. Both are `Option` because either column can be
    /// blank (pit laps, missed markers).
    pub type alias RawMiniSector = {
        time = Option[Duration],
        elapsed = Option[Duration]
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
        crossingFinishLineInPit = Bool,
        s1 = RawSector,
        s2 = RawSector,
        s3 = RawSector,
        kph = String,
        elapsed = Duration,
        hour = Hour,
        topSpeed = String,
        pitTime = Option[Duration],
        flagAtFl = Flag,
        miniSectors = Option[List[(MiniSectorId, RawMiniSector)]]
    }

    pub def decoder(): Decoder[RawLap] =
        Decode.intoRecord(
            car -> driver -> lapNumber -> lapTime -> lapImprovement ->
            crossingFinishLineInPit -> s1 -> s2 -> s3 -> kph -> elapsed -> hour ->
            topSpeed -> pitTime -> flagAtFl -> miniSectors ->
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
                    flagAtFl = flagAtFl,
                    miniSectors = miniSectors
                }
        )
            |> Decode.pipeline(carDecoder())
            |> Decode.pipeline(driverDecoder())
            |> Decode.pipeline(intField("LAP_NUMBER"))
            |> Decode.pipeline(durationField("LAP_TIME"))
            |> Decode.pipeline(improvementField("LAP_IMPROVEMENT"))
            |> Decode.pipeline(boxField("CROSSING_FINISH_LINE_IN_PIT"))
            |> Decode.pipeline(sectorDecoder("S1", "S1_LARGE", "S1_SECONDS", "S1_IMPROVEMENT"))
            |> Decode.pipeline(sectorDecoder("S2", "S2_LARGE", "S2_SECONDS", "S2_IMPROVEMENT"))
            |> Decode.pipeline(sectorDecoder("S3", "S3_LARGE", "S3_SECONDS", "S3_IMPROVEMENT"))
            |> Decode.pipeline(numericStringField("KPH"))
            |> Decode.pipeline(durationField("ELAPSED"))
            |> Decode.pipeline(hourField("HOUR"))
            |> Decode.pipeline(numericOrBlankStringField("TOP_SPEED"))
            |> Decode.pipeline(optionalDurationField("PIT_TIME"))
            |> Decode.pipeline(flagField("FLAG_AT_FL"))
            |> Decode.pipeline(miniSectorsDecoder())

    pub def toJson(rawLap: RawLap): Encode.JsonValue =
        let leadingFields =
            ("carNumber",  JsonString(rawLap#car#carNumber)) ::
            ("lapNumber",  JsonInt(rawLap#lapNumber)) ::
            ("driverName", JsonString(rawLap#driver#name)) ::
            ("lap",        lapToJson(rawLap)) ::
            ("sectors",    sectorsToJson(rawLap)) ::
            Nil;
        let miniFields = match rawLap#miniSectors {
            case None       => Nil
            case Some(list) => ("miniSectors", miniSectorsToJson(list)) :: Nil
        };
        let trailingFields =
            ("elapsed",                 JsonString(Util.Duration.format(rawLap#elapsed))) ::
            ("hour",                    JsonString(HourClock.format(rawLap#hour))) ::
            ("kph",                     JsonString(rawLap#kph)) ::
            ("topSpeed",                JsonString(rawLap#topSpeed)) ::
            ("crossingFinishLineInPit", JsonString(boxToString(rawLap#crossingFinishLineInPit))) ::
            ("pitTime",                 optionalDurationJson(rawLap#pitTime)) ::
            ("flagAtFl",                JsonString(flagToString(rawLap#flagAtFl))) ::
            Nil;
        JsonObject(List.append(leadingFields, List.append(miniFields, trailingFields)))

    def lapToJson(rawLap: RawLap): Encode.JsonValue =
        JsonObject(
            ("time",        JsonString(Util.Duration.format(rawLap#lapTime))) ::
            ("improvement", JsonInt(improvementToInt(rawLap#lapImprovement))) ::
            Nil
        )

    def sectorsToJson(rawLap: RawLap): Encode.JsonValue =
        JsonObject(
            ("s1", sectorToJson(rawLap#s1)) ::
            ("s2", sectorToJson(rawLap#s2)) ::
            ("s3", sectorToJson(rawLap#s3)) ::
            Nil
        )

    def sectorToJson(sector: RawSector): Encode.JsonValue =
        JsonObject(
            ("time",        optionalDurationJson(sector#value)) ::
            ("improvement", JsonInt(improvementToInt(sector#improvement))) ::
            Nil
        )

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

    def checkSectorConsistency(name: String, valueMs: Option[Duration], largeMs: Option[Duration], secondsRaw: String, improvement: Improvement): Result[String, RawSector] =
        match secondsToMillis(name, secondsRaw) {
            case Err(e)       => Err(e)
            case Ok(secondsMs) =>
                let observed = List.filterMap(x -> x, List#{valueMs, largeMs, secondsMs});
                match observed {
                    case Nil           => Ok({ value = valueMs, improvement = improvement })
                    case first :: rest =>
                        if (List.forAll(x -> x == first, rest))
                            Ok({ value = valueMs, improvement = improvement })
                        else
                            Err("${name}: value/large/seconds disagree (value=${valueMs}, large=${largeMs}, seconds=${secondsMs})")
                }
        }

    def secondsToMillis(name: String, raw: String): Result[String, Option[Duration]] =
        if (raw == "") Ok(None)
        else match Float64.fromString(raw) {
            case Some(f) => match Float64.tryToInt32(Float64.round(f * 1000.0)) {
                case Some(ms) => Ok(Some(Util.Duration.fromMillis(ms)))
                case None     => Err("${name}: seconds out of range \"${raw}\"")
            }
            case None => Err("${name}: expected seconds but got \"${raw}\"")
        }

    def stringField(name: String): Decoder[String] =
        Decode.field(name, Decode.string())

    def numericStringField(name: String): Decoder[String] =
        stringField(name) |> Decode.andThen(s -> Decode.fromResult(parseNumericString(name, s)))

    def numericOrBlankStringField(name: String): Decoder[String] =
        stringField(name) |> Decode.andThen(s -> match s {
            case "" => Decode.succeed(s)
            case _  => Decode.fromResult(parseNumericString(name, s))
        })

    def parseNumericString(name: String, s: String): Result[String, String] =
        match Float64.fromString(s) {
            case Some(_) => Ok(s)
            case None    => Err("${name}: expected numeric but got \"${s}\"")
        }

    def intField(name: String): Decoder[Int32] =
        Decode.field(name, Decode.int())

    def durationField(name: String): Decoder[Duration] =
        stringField(name) |> Decode.andThen(s -> Decode.fromResult(parseDuration(name, s)))

    def parseDuration(name: String, raw: String): Result[String, Duration] =
        match Util.Duration.fromString(raw) {
            case Some(d) => Ok(d)
            case None    => Err("${name}: expected duration but got \"${raw}\"")
        }

    def optionalDurationField(name: String): Decoder[Option[Duration]] =
        stringField(name) |> Decode.andThen(s -> Decode.fromResult(parseOptionalDuration(name, s)))

    def parseOptionalDuration(name: String, raw: String): Result[String, Option[Duration]] =
        match Util.Duration.fromString(raw) {
            case Some(d)           => Ok(Some(d))
            case None if raw == "" => Ok(None)
            case None              => Err("${name}: expected duration but got \"${raw}\"")
        }

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

    def boxField(name: String): Decoder[Bool] =
        stringField(name) |> Decode.andThen(s -> match s {
            case "B" => Decode.succeed(true)
            case ""  => Decode.succeed(false)
            case _   => Decode.fail("${name}: expected \"B\" or blank but got \"${s}\"")
        })

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

    def improvementToInt(imp: Improvement): Int32 =
        match imp {
            case Improvement.None        => 0
            case Improvement.DriverBest  => 1
            case Improvement.CarBest     => 2
            case Improvement.OverallBest => 3
        }

    def boxToString(b: Bool): String =
        if (b) "B" else ""

    def flagToString(flag: Flag): String =
        match flag {
            case Flag.Green            => "GF"
            case Flag.SlowZone         => "SF"
            case Flag.FullCourseYellow => "FCY"
            case Flag.Finish           => "FF"
            case Flag.Red              => "RF"
        }

    def optionalDurationJson(d: Option[Duration]): Encode.JsonValue =
        match d {
            case Some(ms) => JsonString(Util.Duration.format(ms))
            case None     => JsonString("")
        }

    /// Decodes the 15 Le Mans mini-sectors. Missing columns (non-Le Mans
    /// CSVs) and blank values both decode to `None`; an all-`None` row
    /// collapses to `None` so `toJson` can omit the `miniSectors` key.
    def miniSectorsDecoder(): Decoder[Option[List[(MiniSectorId, RawMiniSector)]]] =
        Decode.map(collapseIfAllNone, decodeMiniSectorList(MiniSector.all()))

    def decodeMiniSectorList(ids: List[MiniSectorId]): Decoder[List[(MiniSectorId, RawMiniSector)]] =
        Extra.traverse(
            id -> Decode.map(sector -> (id, sector), miniSectorDecoder(id)),
            ids
        )

    def miniSectorDecoder(id: MiniSectorId): Decoder[RawMiniSector] =
        let prefix = MiniSector.csvName(id);
        Decode.map2(
            (time, elapsed) -> { time = time, elapsed = elapsed },
            optionalDurationFromOptionalColumn("${prefix}_time"),
            optionalDurationFromOptionalColumn("${prefix}_elapsed")
        )

    /// Both "header missing" and "blank value" map to `None`.
    def optionalDurationFromOptionalColumn(name: String): Decoder[Option[Duration]] =
        Decode.map(Option.flatten, Decode.optionalField(name, optionalDurationField(name)))

    def collapseIfAllNone(list: List[(MiniSectorId, RawMiniSector)]): Option[List[(MiniSectorId, RawMiniSector)]] =
        let hasAny = List.exists(
            match (_, sector) -> sector#time != None or sector#elapsed != None,
            list
        );
        if (hasAny) Some(list) else None

    def miniSectorsToJson(list: List[(MiniSectorId, RawMiniSector)]): Encode.JsonValue =
        let entries = list |> List.filterMap(match (id, sector) ->
            if (sector#time == None and sector#elapsed == None)
                None
            else
                Some((MiniSector.jsonKey(id), miniSectorToJson(sector)))
        );
        JsonObject(entries)

    def miniSectorToJson(sector: RawMiniSector): Encode.JsonValue =
        JsonObject(
            ("time",    optionalDurationJson(sector#time)) ::
            ("elapsed", optionalDurationJson(sector#elapsed)) ::
            Nil
        )

}
