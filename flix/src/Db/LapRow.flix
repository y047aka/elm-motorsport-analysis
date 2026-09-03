mod Db.LapRow {

    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Motorsport.Wec.RawMiniSector
    use Motorsport.Wec.RawSector
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Db.Row
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
    /// the CSV listed them in is read by `Cli.Validation` for its
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

    /// A PostgreSQL array literal, which is how the values reach a column the
    /// driver would otherwise be told nothing about.
    pub def arrayLiteral(values: List[Option[Int32]]): String =
        "{" + (values |> List.map(v -> match v {
            case Some(n) => "${n}"
            case None    => "NULL"
        }) |> List.join(",")) + "}"

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


    /// A row of the `SELECT` in `Db.Schema.selectRound`, whose columns are
    /// `Db.Schema.columns` in order.
    ///
    /// Read in groups: a `forM` over all twenty-eight at once overflows the
    /// type checker's own stack on a clean build (Flix 0.75.1), on a thread
    /// whose size is the platform's default.
    pub def fromRow(row: List[Option[String]]): Result[String, LapRow] =
        forM(
            round    <- roundColumns(row);
            car      <- carColumns(row);
            lap      <- lapColumns(row);
            sectors  <- sectorColumns(row);
            tail     <- tailColumns(row);
            mini     <- miniSectorColumns(row)
        ) yield {
            season = round#season,
            round = round#round,
            sourceRow = round#sourceRow,
            carNumber = car#carNumber,
            class = car#class,
            carGroup = car#carGroup,
            team = car#team,
            manufacturer = car#manufacturer,
            driverNumber = car#driverNumber,
            driverName = car#driverName,
            lapNumber = lap#lapNumber,
            lapTimeMs = lap#lapTimeMs,
            lapImprovement = lap#lapImprovement,
            crossingFinishLineInPit = lap#crossingFinishLineInPit,
            s1Ms = sectors#s1Ms,
            s1Improvement = sectors#s1Improvement,
            s2Ms = sectors#s2Ms,
            s2Improvement = sectors#s2Improvement,
            s3Ms = sectors#s3Ms,
            s3Improvement = sectors#s3Improvement,
            kph = tail#kph,
            elapsedMs = tail#elapsedMs,
            hourMs = tail#hourMs,
            topSpeed = tail#topSpeed,
            pitTimeMs = tail#pitTimeMs,
            flagAtFl = tail#flagAtFl,
            miniSectorTimeMs = mini#times,
            miniSectorElapsedMs = mini#elapsed
        }

    def roundColumns(row: List[Option[String]]): Result[String, {season = Int32, round = String, sourceRow = Int32}] =
        forM(
            season    <- Row.int(0, row);
            round     <- Row.text(1, row);
            sourceRow <- Row.int(2, row)
        ) yield { season = season, round = round, sourceRow = sourceRow }

    def carColumns(row: List[Option[String]]): Result[String, {carNumber = String, class = String, carGroup = String, team = String, manufacturer = String, driverNumber = Int32, driverName = String}] =
        forM(
            carNumber    <- Row.text(3, row);
            class        <- Row.text(4, row);
            carGroup     <- Row.text(5, row);
            team         <- Row.text(6, row);
            manufacturer <- Row.text(7, row);
            driverNumber <- Row.int(8, row);
            driverName   <- Row.text(9, row)
        ) yield {
            carNumber = carNumber,
            class = class,
            carGroup = carGroup,
            team = team,
            manufacturer = manufacturer,
            driverNumber = driverNumber,
            driverName = driverName
        }

    def lapColumns(row: List[Option[String]]): Result[String, {lapNumber = Int32, lapTimeMs = Int32, lapImprovement = Int32, crossingFinishLineInPit = Bool}] =
        forM(
            lapNumber               <- Row.int(10, row);
            lapTimeMs               <- Row.int(11, row);
            lapImprovement          <- Row.int(12, row);
            crossingFinishLineInPit <- Row.bool(13, row)
        ) yield {
            lapNumber = lapNumber,
            lapTimeMs = lapTimeMs,
            lapImprovement = lapImprovement,
            crossingFinishLineInPit = crossingFinishLineInPit
        }

    def sectorColumns(row: List[Option[String]]): Result[String, {s1Ms = Option[Int32], s1Improvement = Int32, s2Ms = Option[Int32], s2Improvement = Int32, s3Ms = Option[Int32], s3Improvement = Int32}] =
        forM(
            s1Ms          <- Row.optionalInt(14, row);
            s1Improvement <- Row.int(15, row);
            s2Ms          <- Row.optionalInt(16, row);
            s2Improvement <- Row.int(17, row);
            s3Ms          <- Row.optionalInt(18, row);
            s3Improvement <- Row.int(19, row)
        ) yield {
            s1Ms = s1Ms,
            s1Improvement = s1Improvement,
            s2Ms = s2Ms,
            s2Improvement = s2Improvement,
            s3Ms = s3Ms,
            s3Improvement = s3Improvement
        }

    def tailColumns(row: List[Option[String]]): Result[String, {kph = String, elapsedMs = Int32, hourMs = Int32, topSpeed = String, pitTimeMs = Option[Int32], flagAtFl = String}] =
        forM(
            kph       <- Row.text(20, row);
            elapsedMs <- Row.int(21, row);
            hourMs    <- Row.int(22, row);
            topSpeed  <- Row.text(23, row);
            pitTimeMs <- Row.optionalInt(24, row);
            flagAtFl  <- Row.text(25, row)
        ) yield {
            kph = kph,
            elapsedMs = elapsedMs,
            hourMs = hourMs,
            topSpeed = topSpeed,
            pitTimeMs = pitTimeMs,
            flagAtFl = flagAtFl
        }

    def miniSectorColumns(row: List[Option[String]]): Result[String, {times = Option[List[Option[Int32]]], elapsed = Option[List[Option[Int32]]]}] =
        forM(
            times   <- Row.optionalIntArray(26, row);
            elapsed <- Row.optionalIntArray(27, row)
        ) yield { times = times, elapsed = elapsed }

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
