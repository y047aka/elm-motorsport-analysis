mod Motorsport.Metadata {

    use Util.Duration.Duration
    use Util.HourClock
    use Util.HourClock.Hour
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Motorsport.Calendar
    use Motorsport.Car.Car
    use Motorsport.Events
    use Motorsport.Track

    /// What the grid order was derived from. The timing feed carries no
    /// qualifying result, so all three are estimates read back off the race.
    ///
    /// `Lap1S1` is the best of them: `HOUR - ELAPSED` is constant across every
    /// car, so all cars share one timing origin and a back-row car's delay
    /// reaching the line is already inside its S1. Little can change hands
    /// before the first split.
    pub enum Basis with Eq {
        case Lap1S1
        case Lap1Elapsed
        case Unknown
    }

    pub type alias StartingGridEntry = {
        position = Int32,
        car      = Car
    }

    pub type alias StartingGrid = {
        basis   = Basis,
        entries = List[StartingGridEntry]
    }

    /// How far the race ran, and when. The feed states none of it directly.
    ///
    /// `duration` is the observation and `timeLimit` what it is taken to mean:
    /// a WEC round is scheduled in whole hours and the feed never says which.
    /// The two are kept apart so a reader can see the estimate beside what it
    /// was made from, as `Basis` does for the grid order.
    ///
    /// `startedAt` is carried by the feed only as `HOUR - ELAPSED`, a
    /// difference constant across the whole file -- `Cli.Validation`'s
    /// HourElapsedOffset rule is there to say so -- which is why one lap is
    /// enough to read it.
    ///
    /// `lapTotal` counts the laps the leader finished, not the laps in the
    /// file: every car ran its own.
    pub type alias Particulars = {
        startedAt = Option[Hour],
        duration  = Duration,
        timeLimit = Duration,
        lapTotal  = Int32
    }

    /// The laps say nothing about which round they are -- no column carries the
    /// year, and the same race is run again the next one -- so that arrives from
    /// outside, as the calendar entry the run was working through. Which is why
    /// `season` and `date` are certain: without them the file was never opened.
    pub type alias Metadata = {
        name         = String,
        season       = Int32,
        date         = String,
        race         = Particulars,
        track        = Track.Track,
        startingGrid = StartingGrid
    }

    /// What a car was, and the two readings the grid order can be made from.
    /// The list is in the order the file first showed the cars, which is the
    /// order a tie falls back to.
    pub type alias CarBuild = {
        car         = Car,
        lap1S1      = Option[Duration],
        lap1Elapsed = Option[Duration]
    }

    pub def fromReadings(
        entry: Calendar.Entry,
        race: Particulars,
        track: Track.Track,
        builds: List[CarBuild]
    ): Metadata =
        {
            name         = Events.displayName(entry#id),
            season       = entry#season,
            date         = entry#date,
            race         = race,
            track        = track,
            startingGrid = estimateGrid(builds)
        }

    pub def particulars(startedAt: Option[Hour], duration: Duration, lapTotal: Int32): Particulars =
        {
            startedAt = startedAt,
            duration  = duration,
            timeLimit = floorToHour(duration),
            lapTotal  = lapTotal
        }

    def floorToHour(d: Duration): Duration =
        let hourMs = 3600000;
        Util.Duration.fromMillis((Util.Duration.millis(d) / hourMs) * hourMs)

    pub def estimateGrid(builds: List[CarBuild]): StartingGrid =
        let basis = basisOf(builds);
        let entries = builds
            |> List.sortBy(b -> orderingKey(basis, b))
            |> List.zipWithIndex
            |> List.map(p -> match p { case (i, b) => { position = i + 1, car = b#car } });
        {
            basis   = basis,
            entries = entries
        }

    /// Chosen once for the whole grid, so what gets compared is always the same
    /// measurement: a first split weighed against another car's whole first lap
    /// would order the two by their units rather than by their pace. A car that
    /// turned no first lap can be read by neither, so it does not cost the rest
    /// of the field its S1.
    def basisOf(builds: List[CarBuild]): Basis =
        let readable = builds |> List.filter(b -> b#lap1Elapsed != None);
        if (List.isEmpty(readable))
            Basis.Unknown
        else if (List.forAll(b -> b#lap1S1 != None, readable))
            Basis.Lap1S1
        else
            Basis.Lap1Elapsed

    def readingFor(basis: Basis, b: CarBuild): Option[Duration] =
        match basis {
            case Basis.Lap1S1      => b#lap1S1
            case Basis.Lap1Elapsed => b#lap1Elapsed
            case Basis.Unknown     => None
        }

    /// The tie-breaks are here so that the same input always yields the same
    /// output and the CSV's row order never leaks in. The last of them compares
    /// car numbers as the strings they are: any total order settles a tie, and
    /// reading them as numbers would dress the position up as a ranking it is
    /// not making -- nor would it be one-to-one, since Le Mans runs #7 alongside
    /// #007.
    ///
    /// A car with no first lap is placed rather than dropped: it did start the
    /// race, and the back is where being wrong costs the least.
    def orderingKey(basis: Basis, b: CarBuild): (Int32, Duration, Duration, String) =
        let cn = b#car#carNumber;
        let elapsed = b#lap1Elapsed |> Option.getWithDefault(Util.Duration.zero());
        match readingFor(basis, b) {
            case Some(reading) => (0, reading, elapsed, cn)
            case None          => (1, Util.Duration.zero(), Util.Duration.zero(), cn)
        }

    pub def toJson(meta: Metadata): Encode.JsonValue =
        JsonObject(
            ("name",         JsonString(meta#name)) ::
            ("season",       JsonInt(meta#season)) ::
            ("date",         JsonString(meta#date)) ::
            ("race",         particularsToJson(meta#race)) ::
            ("track",        Track.toJson(meta#track)) ::
            ("startingGrid", gridToJson(meta#startingGrid)) ::
            Nil
        )

    def particularsToJson(p: Particulars): Encode.JsonValue =
        let startedAt = match p#startedAt {
            case None    => Nil
            case Some(h) => ("startedAt", JsonString(HourClock.format(h))) :: Nil
        };
        JsonObject(List.append(startedAt,
            ("duration",  JsonString(Util.Duration.format(p#duration))) ::
            ("timeLimit", JsonString(Util.Duration.format(p#timeLimit))) ::
            ("lapTotal",  JsonInt(p#lapTotal)) ::
            Nil
        ))

    def gridToJson(grid: StartingGrid): Encode.JsonValue =
        JsonObject(
            ("basis",   JsonString(basisToString(grid#basis))) ::
            ("entries", JsonArray(grid#entries |> List.map(toGridEntryJson))) ::
            Nil
        )

    def basisToString(basis: Basis): String =
        match basis {
            case Basis.Lap1S1      => "lap1_s1"
            case Basis.Lap1Elapsed => "lap1_elapsed"
            case Basis.Unknown     => "unknown"
        }

    def toGridEntryJson(entry: StartingGridEntry): Encode.JsonValue =
        JsonObject(
            ("position", JsonInt(entry#position)) ::
            ("car",      carToJson(entry#car)) ::
            Nil
        )

    def carToJson(car: Car): Encode.JsonValue =
        JsonObject(
            ("carNumber",    JsonString(car#carNumber)) ::
            ("drivers",      JsonArray(car#drivers |> List.map(driverToJson))) ::
            ("class",        JsonString(car#class)) ::
            ("group",        JsonString(car#group)) ::
            ("team",         JsonString(car#team)) ::
            ("manufacturer", JsonString(car#manufacturer)) ::
            Nil
        )

    def driverToJson(name: String): Encode.JsonValue =
        JsonObject(("name", JsonString(name)) :: Nil)

}
