mod Motorsport.Metadata {

    use Util.Duration.Duration
    use Util.HourClock
    use Util.HourClock.Hour
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Motorsport.Car.Car
    use Motorsport.Events
    use Motorsport.Track
    use Motorsport.Wec.RawLap

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

    /// How far the race ran, and when. Every one of these is read back off the
    /// laps, because the feed states none of them directly.
    ///
    /// `duration` is the observation -- the last moment any car crossed the
    /// line -- and `timeLimit` is what that is taken to mean: the scheduled
    /// distance, which for every WEC round is a whole number of hours, so the
    /// observation rounded down to the hour. The two are kept apart rather than
    /// collapsed so a reader can see the estimate and what it was made from, in
    /// the way `Basis` says where the grid order came from.
    ///
    /// `startedAt` is the time of day the race got under way, which the feed
    /// carries only as `HOUR - ELAPSED`. That difference is constant across the
    /// whole file -- `Cli.Stages.Validation`'s HourElapsedOffset rule is there
    /// to say so -- which is why one lap is enough to read it.
    ///
    /// `lapTotal` is the highest lap number anyone completed, which is the lap
    /// the leader finished on and so what the lap counter counts up to. It is
    /// not the number of laps in the file: every car ran its own.
    pub type alias Particulars = {
        startedAt = Option[Hour],
        duration  = Duration,
        timeLimit = Duration,
        lapTotal  = Int32
    }

    /// `season` is read off the path the CSV came in on rather than out of the
    /// laps, which say nothing about the year -- see
    /// [`Cli.FileTask`](Cli.FileTask)'s `season`. A file filed outside a season
    /// directory has none, and the key is left out.
    pub type alias Metadata = {
        name         = String,
        season       = Option[Int32],
        race         = Particulars,
        track        = Track.Track,
        startingGrid = StartingGrid
    }

    pub def fromRawLaps(eventId: String, season: Option[Int32], rawLaps: List[RawLap]): Metadata =
        let builds = buildCars(rawLaps);
        {
            name         = Events.displayName(eventId),
            season       = season,
            race         = particularsOf(rawLaps),
            track        = Track.fromRawLaps(rawLaps),
            startingGrid = estimateGrid(builds)
        }

    def particularsOf(rawLaps: List[RawLap]): Particulars =
        let duration = rawLaps |> List.foldLeft((acc, lap) -> laterOf(acc, lap#elapsed), Util.Duration.zero());
        {
            startedAt = rawLaps |> List.head |> Option.map(startedAtOf),
            duration  = duration,
            timeLimit = floorToHour(duration),
            lapTotal  = rawLaps |> List.foldLeft((acc, lap) -> Int32.max(acc, lap#lapNumber), 0)
        }

    def laterOf(a: Duration, b: Duration): Duration =
        if (Util.Duration.millis(b) > Util.Duration.millis(a)) b else a

    /// `offsetFrom` folds the day-rollover in, so a lap turned after midnight
    /// reads back the same start as the first one.
    def startedAtOf(lap: RawLap): Hour =
        Hour.Hour(HourClock.offsetFrom(lap#hour, Util.Duration.millis(lap#elapsed)))

    def floorToHour(d: Duration): Duration =
        let hourMs = 3600000;
        Util.Duration.fromMillis((Util.Duration.millis(d) / hourMs) * hourMs)

    type alias CarBuild = {
        car         = Car,
        lap1S1      = Option[Duration],
        lap1Elapsed = Option[Duration]
    }

    def buildCars(rawLaps: List[RawLap]): List[CarBuild] =
        rawLaps |> List.foldLeft((acc, lap) -> upsertBuild(acc, lap), Nil)

    def upsertBuild(acc: List[CarBuild], lap: RawLap): List[CarBuild] =
        if (List.exists(b -> b#car#carNumber == lap#car#carNumber, acc))
            acc |> List.map(b ->
                if (b#car#carNumber == lap#car#carNumber) updateBuildWithLap(b, lap) else b
            )
        else
            List.append(acc, buildFromLap(lap) :: Nil)

    def buildFromLap(lap: RawLap): CarBuild =
        // The Rust version normalizes unknown class values to Class::None; omitted because the Elm side consumes the raw values.
        let car: Car = {
            carNumber    = lap#car#carNumber,
            drivers      = lap#driver#name :: Nil,
            class        = lap#car#class,
            group        = lap#car#group,
            team         = lap#car#team,
            manufacturer = lap#car#manufacturer
        };
        { car = car, lap1S1 = lap1S1(lap), lap1Elapsed = lap1Elapsed(lap) }

    def updateBuildWithLap(build: CarBuild, lap: RawLap): CarBuild =
        let updatedCar = { drivers = appendUnique(build#car#drivers, lap#driver#name) | build#car };
        {
            car         = updatedCar,
            lap1S1      = keepFirst(build#lap1S1, lap1S1(lap)),
            lap1Elapsed = keepFirst(build#lap1Elapsed, lap1Elapsed(lap))
        }

    def keepFirst(seen: Option[Duration], candidate: Option[Duration]): Option[Duration] =
        match seen {
            case Some(_) => seen
            case None    => candidate
        }

    def lap1S1(lap: RawLap): Option[Duration] =
        if (lap#lapNumber == 1) lap#s1#value
        else None

    def lap1Elapsed(lap: RawLap): Option[Duration] =
        if (lap#lapNumber == 1) Some(lap#elapsed)
        else None

    def appendUnique(xs: List[String], x: String): List[String] =
        if (List.memberOf(x, xs)) xs
        else List.append(xs, x :: Nil)

    def estimateGrid(builds: List[CarBuild]): StartingGrid =
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
        let season = match meta#season {
            case None    => Nil
            case Some(y) => ("season", JsonInt(y)) :: Nil
        };
        JsonObject(
            ("name", JsonString(meta#name)) ::
            List.append(season,
                ("race",         particularsToJson(meta#race)) ::
                ("track",        Track.toJson(meta#track)) ::
                ("startingGrid", gridToJson(meta#startingGrid)) ::
                Nil
            )
        )

    /// A race with no laps in it has no time of day to report, so the key is
    /// left out rather than filled with midnight -- the same choice
    /// `Motorsport.Wec` makes for a lap with no mini-sectors.
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
