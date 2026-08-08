mod Motorsport.Metadata {

    use Util.Duration.Duration
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Motorsport.Car.Car
    use Motorsport.Events
    use Motorsport.Wec.RawLap

    /// What the grid order was derived from. The timing feed carries no
    /// qualifying result, so every basis below is an *estimate* read back off
    /// the race itself; `position` is exact only once a basis appears that
    /// names a published grid. Every car is placed either way -- this is what
    /// says how much of the placing to believe.
    ///
    /// `Lap1S1` is the best of them: `HOUR - ELAPSED` is constant across every
    /// car and every lap, so all cars share one timing origin and a back-row
    /// car's delay reaching the line is already inside its S1. Little can
    /// change hands before the first split.
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

    /// The lap-1 reading is taken from the first lap-1 record seen and never
    /// overwritten by a later one.
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

    /// Every car gets a place, so the list is a permutation of the entry list:
    /// 1..n, each exactly once, in position order.
    def estimateGrid(builds: List[CarBuild]): StartingGrid =
        let entries = builds
            |> List.sortBy(orderingKey)
            |> List.zipWithIndex
            |> List.map(p -> match p { case (i, b) => { position = i + 1, car = b#car } });
        {
            basis   = basisOf(builds),
            entries = entries
        }

    /// Lap-1 S1, falling back to lap-1 elapsed. Ties break on lap-1 elapsed and
    /// then on car number, so the order is decided by the data alone and never
    /// by the order the CSV happened to list the cars in.
    ///
    /// A car with no lap-1 record at all cannot be read, so nothing about where
    /// it started is known. It is still placed rather than dropped -- it did
    /// start the race -- and goes to the back in car-number order, where being
    /// wrong costs the least. `basis` is what says how much of the order to
    /// trust; the entry itself does not claim to be measured.
    def orderingKey(b: CarBuild): (Int32, Duration, Duration, Int32, String) =
        let cn = b#car#carNumber;
        let num = numericCarNumber(cn);
        match (b#lap1S1, b#lap1Elapsed) {
            case (Some(s1), Some(el)) => (0, s1, el, num, cn)
            case (Some(s1), None)     => (0, s1, s1, num, cn)
            case (None, Some(el))     => (0, el, el, num, cn)
            case (None, None)         => (1, Util.Duration.zero(), Util.Duration.zero(), num, cn)
        }

    /// "7" sorts before "12"; anything that is not a number sorts after both.
    def numericCarNumber(cn: String): Int32 =
        Int32.fromString(cn) |> Option.getWithDefault(Int32.maxValue())

    /// Names the rule the whole list was ordered by, fallbacks included.
    def basisOf(builds: List[CarBuild]): Basis =
        if (List.exists(b -> b#lap1S1 != None, builds))
            Basis.Lap1S1
        else if (List.exists(b -> b#lap1Elapsed != None, builds))
            Basis.Lap1Elapsed
        else
            Basis.Unknown

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
