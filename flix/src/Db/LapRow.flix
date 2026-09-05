mod Db.LapRow {

    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Motorsport.Wec.RawMiniSector
    use Motorsport.Wec.RawSector
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Sql.Sel
    use Util.Duration
    use Util.HourClock

    /// One row of `laps`. A column takes the type the Flix value already has:
    /// a `Duration` is the milliseconds it holds, and `kph` / `topSpeed` stay
    /// the text the feed gave, so nothing here parses or rounds anything the
    /// decoder did not.
    ///
    /// The mini-sectors are the fifteen of `Motorsport.MiniSector.all()` in
    /// track order, so a position in either list is a place on the circuit and
    /// a `None` is a marker the feed left blank. `None` for the pair itself is
    /// a round that measured none.
    ///
    /// `sourceRow` counts the file's laps from one, header excluded. The order
    /// the CSV listed them in is read by `Cli.Load.Validation` for its
    /// baseline and by `Motorsport.Metadata` for a car's drivers, and no other
    /// column here can be sorted on to recover it.
    pub type alias LapRow = {
        season = Int32,
        round = String,
        sourceRow = Int32,
        carNumber = String,
        class = String,
        carGroup = String,
        team = String,
        manufacturer = String,
        driverNumber = Int32,
        driverName = String,
        lapNumber = Int32,
        lapTimeMs = Int32,
        lapImprovement = Int32,
        crossingFinishLineInPit = Bool,
        s1Ms = Option[Int32],
        s1Improvement = Int32,
        s2Ms = Option[Int32],
        s2Improvement = Int32,
        s3Ms = Option[Int32],
        s3Improvement = Int32,
        kph = String,
        elapsedMs = Int32,
        hourMs = Int32,
        topSpeed = String,
        pitTimeMs = Option[Int32],
        flagAtFl = String,
        miniSectorTimeMs = Option[List[Option[Int32]]],
        miniSectorElapsedMs = Option[List[Option[Int32]]]
    }

    /// A bound value, in the type its column has.
    pub enum Value with Eq, ToString {
        case Text(String)
        case Integer(Int32)
        case Boolean(Bool)
        case NullableInteger(Option[Int32])
        case NullableIntArray(Option[List[Option[Int32]]])
    }

    pub def fromRawLaps(entry: Entry, rawLaps: List[RawLap]): List[LapRow] =
        rawLaps
            |> List.zipWithIndex
            |> List.map(pair -> match pair {
                case (index, rawLap) => fromRawLap(entry, index + 1, rawLap)
            })

    pub def fromRawLap(entry: Entry, sourceRow: Int32, rawLap: RawLap): LapRow =
        {
            season = entry#season,
            round = entry#id,
            sourceRow = sourceRow,
            carNumber = rawLap#car#carNumber,
            class = rawLap#car#class,
            carGroup = rawLap#car#group,
            team = rawLap#car#team,
            manufacturer = rawLap#car#manufacturer,
            driverNumber = rawLap#driver#number,
            driverName = rawLap#driver#name,
            lapNumber = rawLap#lapNumber,
            lapTimeMs = Duration.millis(rawLap#lapTime),
            lapImprovement = Wec.improvementToInt(rawLap#lapImprovement),
            crossingFinishLineInPit = rawLap#crossingFinishLineInPit,
            s1Ms = sectorMs(rawLap#s1),
            s1Improvement = Wec.improvementToInt(rawLap#s1#improvement),
            s2Ms = sectorMs(rawLap#s2),
            s2Improvement = Wec.improvementToInt(rawLap#s2#improvement),
            s3Ms = sectorMs(rawLap#s3),
            s3Improvement = Wec.improvementToInt(rawLap#s3#improvement),
            kph = rawLap#kph,
            elapsedMs = Duration.millis(rawLap#elapsed),
            hourMs = HourClock.msSinceMidnight(rawLap#hour),
            topSpeed = rawLap#topSpeed,
            pitTimeMs = Option.map(Duration.millis, rawLap#pitTime),
            flagAtFl = Wec.flagToString(rawLap#flagAtFl),
            miniSectorTimeMs = miniSectorMs(sector -> sector#time, rawLap),
            miniSectorElapsedMs = miniSectorMs(sector -> sector#elapsed, rawLap)
        }

    def miniSectorMs(reading: RawMiniSector -> Option[Duration.Duration], rawLap: RawLap): Option[List[Option[Int32]]] =
        rawLap#miniSectors |> Option.map(List.map(match (_, sector) ->
            reading(sector) |> Option.map(Duration.millis)
        ))

    /// The text a mini-sector column holds, which `json_each` reads back as
    /// one row per marker.
    pub def jsonArray(values: List[Option[Int32]]): String =
        "[" + (values |> List.map(v -> match v {
            case Some(n) => "${n}"
            case None    => "null"
        }) |> List.join(",")) + "]"

    /// In the order `Db.Schema.columns` names them.
    pub def values(row: LapRow): List[Value] =
        Value.Integer(row#season) ::
        Value.Text(row#round) ::
        Value.Integer(row#sourceRow) ::
        Value.Text(row#carNumber) ::
        Value.Text(row#class) ::
        Value.Text(row#carGroup) ::
        Value.Text(row#team) ::
        Value.Text(row#manufacturer) ::
        Value.Integer(row#driverNumber) ::
        Value.Text(row#driverName) ::
        Value.Integer(row#lapNumber) ::
        Value.Integer(row#lapTimeMs) ::
        Value.Integer(row#lapImprovement) ::
        Value.Boolean(row#crossingFinishLineInPit) ::
        Value.NullableInteger(row#s1Ms) ::
        Value.Integer(row#s1Improvement) ::
        Value.NullableInteger(row#s2Ms) ::
        Value.Integer(row#s2Improvement) ::
        Value.NullableInteger(row#s3Ms) ::
        Value.Integer(row#s3Improvement) ::
        Value.Text(row#kph) ::
        Value.Integer(row#elapsedMs) ::
        Value.Integer(row#hourMs) ::
        Value.Text(row#topSpeed) ::
        Value.NullableInteger(row#pitTimeMs) ::
        Value.Text(row#flagAtFl) ::
        Value.NullableIntArray(row#miniSectorTimeMs) ::
        Value.NullableIntArray(row#miniSectorElapsedMs) ::
        Nil


    /// A round's laps as the table holds them, naming the columns
    /// `Db.Schema.columns` names and in that order.
    pub def selection(): Sel[LapRow] =
        Sql.intoRow(season -> round -> sourceRow -> carNumber -> class -> carGroup -> team -> manufacturer -> driverNumber -> driverName -> lapNumber -> lapTimeMs -> lapImprovement -> crossingFinishLineInPit -> s1Ms -> s1Improvement -> s2Ms -> s2Improvement -> s3Ms -> s3Improvement -> kph -> elapsedMs -> hourMs -> topSpeed -> pitTimeMs -> flagAtFl -> times -> elapsed -> {
            season = season, round = round, sourceRow = sourceRow, carNumber = carNumber,
            class = class, carGroup = carGroup, team = team, manufacturer = manufacturer,
            driverNumber = driverNumber, driverName = driverName, lapNumber = lapNumber,
            lapTimeMs = lapTimeMs, lapImprovement = lapImprovement,
            crossingFinishLineInPit = crossingFinishLineInPit,
            s1Ms = s1Ms, s1Improvement = s1Improvement, s2Ms = s2Ms, s2Improvement = s2Improvement,
            s3Ms = s3Ms, s3Improvement = s3Improvement, kph = kph, elapsedMs = elapsedMs,
            hourMs = hourMs, topSpeed = topSpeed, pitTimeMs = pitTimeMs, flagAtFl = flagAtFl,
            miniSectorTimeMs = times, miniSectorElapsedMs = elapsed
        })
            |> Sql.pipeline(Sql.int("season"))
            |> Sql.pipeline(Sql.text("round"))
            |> Sql.pipeline(Sql.int("source_row"))
            |> Sql.pipeline(Sql.text("car_number"))
            |> Sql.pipeline(Sql.text("class"))
            |> Sql.pipeline(Sql.text("car_group"))
            |> Sql.pipeline(Sql.text("team"))
            |> Sql.pipeline(Sql.text("manufacturer"))
            |> Sql.pipeline(Sql.int("driver_number"))
            |> Sql.pipeline(Sql.text("driver_name"))
            |> Sql.pipeline(Sql.int("lap_number"))
            |> Sql.pipeline(Sql.int("lap_time_ms"))
            |> Sql.pipeline(Sql.int("lap_improvement"))
            |> Sql.pipeline(Sql.bool("crossing_finish_line_in_pit"))
            |> Sql.pipeline(Sql.optionalInt("s1_ms"))
            |> Sql.pipeline(Sql.int("s1_improvement"))
            |> Sql.pipeline(Sql.optionalInt("s2_ms"))
            |> Sql.pipeline(Sql.int("s2_improvement"))
            |> Sql.pipeline(Sql.optionalInt("s3_ms"))
            |> Sql.pipeline(Sql.int("s3_improvement"))
            |> Sql.pipeline(Sql.text("kph"))
            |> Sql.pipeline(Sql.int("elapsed_ms"))
            |> Sql.pipeline(Sql.int("hour_ms"))
            |> Sql.pipeline(Sql.text("top_speed"))
            |> Sql.pipeline(Sql.optionalInt("pit_time_ms"))
            |> Sql.pipeline(Sql.text("flag_at_fl"))
            |> Sql.pipeline(Sql.optionalIntArray("mini_sector_time_ms"))
            |> Sql.pipeline(Sql.optionalIntArray("mini_sector_elapsed_ms"))

    pub def toRawLap(row: LapRow): Result[String, RawLap] =
        forM(
            lapImprovement <- improvement("LAP_IMPROVEMENT", row#lapImprovement);
            s1Improvement  <- improvement("S1_IMPROVEMENT", row#s1Improvement);
            s2Improvement  <- improvement("S2_IMPROVEMENT", row#s2Improvement);
            s3Improvement  <- improvement("S3_IMPROVEMENT", row#s3Improvement);
            flagAtFl       <- flag(row#flagAtFl)
        ) yield {
            car = {
                carNumber    = row#carNumber,
                class        = row#class,
                group        = row#carGroup,
                team         = row#team,
                manufacturer = row#manufacturer
            },
            driver = { number = row#driverNumber, name = row#driverName },
            lapNumber = row#lapNumber,
            lapTime = Duration.fromMillis(row#lapTimeMs),
            lapImprovement = lapImprovement,
            crossingFinishLineInPit = row#crossingFinishLineInPit,
            s1 = { value = Option.map(Duration.fromMillis, row#s1Ms), improvement = s1Improvement },
            s2 = { value = Option.map(Duration.fromMillis, row#s2Ms), improvement = s2Improvement },
            s3 = { value = Option.map(Duration.fromMillis, row#s3Ms), improvement = s3Improvement },
            kph = row#kph,
            elapsed = Duration.fromMillis(row#elapsedMs),
            hour = HourClock.Hour.Hour(row#hourMs),
            topSpeed = row#topSpeed,
            pitTime = Option.map(Duration.fromMillis, row#pitTimeMs),
            flagAtFl = flagAtFl,
            miniSectors = miniSectors(row)
        }

    def improvement(column: String, value: Int32): Result[String, Wec.Improvement] =
        Wec.improvementFromInt(value)
            |> Option.toOk("${column} is not 0/1/2/3: ${value}")

    def flag(value: String): Result[String, Wec.Flag] =
        Wec.flagFromString(value)
            |> Option.toOk("FLAG_AT_FL is not GF/SF/FCY/FF/RF: \"${value}\"")

    def miniSectors(row: LapRow): Option[List[(MiniSectorId, RawMiniSector)]] =
        match (row#miniSectorTimeMs, row#miniSectorElapsedMs) {
            case (Some(times), Some(elapsed)) =>
                Some(List.zip(MiniSector.all(), List.zip(times, elapsed))
                    |> List.map(match (id, (time, cumulative)) -> (id, {
                        time    = Option.map(Duration.fromMillis, time),
                        elapsed = Option.map(Duration.fromMillis, cumulative)
                    })))
            case _ => None
        }

    def sectorMs(sector: RawSector): Option[Int32] =
        Option.map(Duration.millis, sector#value)

}
