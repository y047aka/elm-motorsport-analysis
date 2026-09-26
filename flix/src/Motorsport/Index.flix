/// The race's indices: the moments the lap counter went up, the moments each
/// of the nineteen records changed hands, and the moments the field's flag
/// changed.
///
/// The mirror of `Motorsport.Race.Index` on the Elm side, which reads these
/// back out of the summary.
mod Motorsport.Index {

    use Motorsport.Flag.FlagShown
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Motorsport.Sector
    use Motorsport.Sector.Sector
    use Util.Duration.Duration
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}

    /// A record and the lap that set it. `time` is the record itself -- the lap
    /// time, the sector time, the mini-sector time -- not the time of the lap
    /// it was set on, which for a sector record is a different number entirely.
    pub type alias Change = {
        elapsed   = Duration,
        time      = Duration,
        carNumber = String,
        lap       = Int32,
        driver    = String
    }

    /// The nineteen a timing screen rates against: the fastest lap, three
    /// sectors and fifteen mini-sectors.
    pub enum Record with Eq {
        case FastestLap
        case FastestSector(Sector)
        case FastestMiniSector(MiniSectorId)
    }

    /// Enumerated once, so a record cannot be read out of the rows and then go
    /// missing from what is written.
    pub def records(): List[Record] =
        Record.FastestLap ::
        List.append(
            Sector.all() |> List.map(s -> Record.FastestSector(s)),
            MiniSector.all() |> List.map(m -> Record.FastestMiniSector(m))
        )

    /// When the lap counter went up and to what, every change of hands, each
    /// record with its own list in the order they were set, and every flag the
    /// field was shown in the order the line read them.
    pub type alias Index = {
        lapCompletions = List[(Int32, Duration)],
        bestTimes      = List[(Record, List[Change])],
        flags          = List[FlagShown]
    }

    pub def empty(): Index =
        { lapCompletions = Nil, bestTimes = Nil, flags = Nil }

    pub def changesOf(record: Record, index: Index): List[Change] =
        index#bestTimes
            |> List.filterMap(match (r, changes) -> if (r == record) Some(changes) else None)
            |> List.flatten

    pub def toJson(index: Index): Encode.JsonValue =
        JsonObject(
            ("lapCompletions",  JsonArray(index#lapCompletions |> List.map(completionToJson))) ::
            ("bestTimeChanges", bestTimesToJson(index)) ::
            ("flagChanges",     JsonArray(index#flags |> List.map(flagToJson))) ::
            Nil
        )

    def flagToJson(shown: FlagShown): Encode.JsonValue =
        JsonObject(
            ("elapsed", JsonString(Util.Duration.format(shown#elapsed))) ::
            ("flag",    JsonString(Motorsport.Flag.toString(shown#flag))) ::
            Nil
        )

    def completionToJson(completion: (Int32, Duration)): Encode.JsonValue =
        match completion {
            case (lap, elapsed) =>
                JsonObject(
                    ("lap",     JsonInt(lap)) ::
                    ("elapsed", JsonString(Util.Duration.format(elapsed))) ::
                    Nil
                )
        }

    def bestTimesToJson(index: Index): Encode.JsonValue =
        JsonObject(
            ("fastestLapTime", changesToJson(Record.FastestLap, index)) ::
            ("sectors", JsonObject(Sector.all() |> List.map(s ->
                (Sector.jsonKey(s), changesToJson(Record.FastestSector(s), index))))) ::
            ("miniSectors", JsonObject(MiniSector.all() |> List.map(m ->
                (MiniSector.jsonKey(m), changesToJson(Record.FastestMiniSector(m), index))))) ::
            Nil
        )

    def changesToJson(record: Record, index: Index): Encode.JsonValue =
        JsonArray(changesOf(record, index) |> List.map(changeToJson))

    def changeToJson(change: Change): Encode.JsonValue =
        JsonObject(
            ("elapsed",   JsonString(Util.Duration.format(change#elapsed))) ::
            ("time",      JsonString(Util.Duration.format(change#time))) ::
            ("carNumber", JsonString(change#carNumber)) ::
            ("lap",       JsonInt(change#lap)) ::
            ("driver",    JsonString(change#driver)) ::
            Nil
        )

}
