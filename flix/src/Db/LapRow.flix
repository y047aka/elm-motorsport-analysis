mod Db.LapRow {

    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Motorsport.Wec.RawMiniSector
    use Motorsport.Wec.RawSector
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Db.Laps
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

    /// A round's laps as the table holds them, a field at a time: each line
    /// names the column and the field its cell lands in, and a field left out
    /// is not a `LapRow`.
    pub def selection(): Sel[LapRow] =
        let c = Laps.columns();
        Sql.record({})
            |> Sql.field(c#season, (row, value) -> { +season = value | row })
            |> Sql.field(c#round, (row, value) -> { +round = value | row })
            |> Sql.field(c#sourceRow, (row, value) -> { +sourceRow = value | row })
            |> Sql.field(c#carNumber, (row, value) -> { +carNumber = value | row })
            |> Sql.field(c#carClass, (row, value) -> { +class = value | row })
            |> Sql.field(c#carGroup, (row, value) -> { +carGroup = value | row })
            |> Sql.field(c#team, (row, value) -> { +team = value | row })
            |> Sql.field(c#manufacturer, (row, value) -> { +manufacturer = value | row })
            |> Sql.field(c#driverNumber, (row, value) -> { +driverNumber = value | row })
            |> Sql.field(c#driverName, (row, value) -> { +driverName = value | row })
            |> Sql.field(c#lapNumber, (row, value) -> { +lapNumber = value | row })
            |> Sql.field(c#lapTimeMs, (row, value) -> { +lapTimeMs = value | row })
            |> Sql.field(c#lapImprovement, (row, value) -> { +lapImprovement = value | row })
            |> Sql.field(c#crossingFinishLineInPit, (row, value) -> { +crossingFinishLineInPit = value | row })
            |> Sql.field(c#s1Ms, (row, value) -> { +s1Ms = value | row })
            |> Sql.field(c#s1Improvement, (row, value) -> { +s1Improvement = value | row })
            |> Sql.field(c#s2Ms, (row, value) -> { +s2Ms = value | row })
            |> Sql.field(c#s2Improvement, (row, value) -> { +s2Improvement = value | row })
            |> Sql.field(c#s3Ms, (row, value) -> { +s3Ms = value | row })
            |> Sql.field(c#s3Improvement, (row, value) -> { +s3Improvement = value | row })
            |> Sql.field(c#kph, (row, value) -> { +kph = value | row })
            |> Sql.field(c#elapsedMs, (row, value) -> { +elapsedMs = value | row })
            |> Sql.field(c#hourMs, (row, value) -> { +hourMs = value | row })
            |> Sql.field(c#topSpeed, (row, value) -> { +topSpeed = value | row })
            |> Sql.field(c#pitTimeMs, (row, value) -> { +pitTimeMs = value | row })
            |> Sql.field(c#flagAtFl, (row, value) -> { +flagAtFl = value | row })
            |> Sql.field(c#miniSectorTimeMs, (row, value) -> { +miniSectorTimeMs = value | row })
            |> Sql.field(c#miniSectorElapsedMs, (row, value) -> { +miniSectorElapsedMs = value | row })

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
