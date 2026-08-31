mod Cli.Db.LapRow {

    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Motorsport.Wec.RawMiniSector
    use Motorsport.Wec.RawSector
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
    /// the CSV listed them in is read by `Cli.Stages.Validation` for its
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

    /// In the order `Cli.Db.Schema.columns` names them.
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

    def sectorMs(sector: RawSector): Option[Int32] =
        Option.map(Duration.millis, sector#value)

}
