mod Motorsport.Metadata {

    use Util.Duration.Duration
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Motorsport.Car.Car
    use Motorsport.Events
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

    pub type alias Metadata = {
        name         = String,
        startingGrid = StartingGrid
    }

    pub def fromRawLaps(eventId: String, rawLaps: List[RawLap]): Metadata =
        let builds = buildCars(rawLaps);
        {
            name         = Events.displayName(eventId),
            startingGrid = estimateGrid(builds)
        }

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
        JsonObject(
            ("name",         JsonString(meta#name)) ::
            ("startingGrid", gridToJson(meta#startingGrid)) ::
            Nil
        )

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
