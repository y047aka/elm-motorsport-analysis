mod Motorsport.Metadata {

    use Util.Duration
    use Util.Json
    use Util.Json.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Motorsport.Car.Car
    use Motorsport.Events
    use Motorsport.RawLap.RawLap

    pub type alias StartingGrid = {
        position = Int32,
        car      = Car
    }

    pub type alias Metadata = {
        name         = String,
        startingGrid = List[StartingGrid]
    }

    pub def fromRawLaps(eventId: String, rawLaps: List[RawLap]): Metadata =
        let builds = buildCars(rawLaps);
        {
            name         = Events.displayName(eventId),
            startingGrid = assignStartPositions(builds)
        }

    type alias CarBuild = {
        car         = Car,
        lap1Elapsed = Option[Int32]
    }

    def buildCars(rawLaps: List[RawLap]): List[CarBuild] =
        rawLaps |> List.foldLeft((acc, lap) -> upsertBuild(acc, lap), Nil)

    def upsertBuild(acc: List[CarBuild], lap: RawLap): List[CarBuild] =
        if (List.exists(b -> b#car#carNumber == lap#carNumber, acc))
            acc |> List.map(b ->
                if (b#car#carNumber == lap#carNumber) updateBuildWithLap(b, lap) else b
            )
        else
            List.append(acc, buildFromLap(lap) :: Nil)

    def buildFromLap(lap: RawLap): CarBuild =
        // The Rust version normalizes unknown class values to Class::None; omitted because the Elm side consumes the raw values.
        let car: Car = {
            carNumber    = lap#carNumber,
            drivers      = lap#driverName :: Nil,
            class        = lap#class,
            group        = lap#group,
            team         = lap#team,
            manufacturer = lap#manufacturer
        };
        { car = car, lap1Elapsed = lap1Elapsed(lap) }

    def updateBuildWithLap(build: CarBuild, lap: RawLap): CarBuild =
        let updatedCar = { drivers = appendUnique(build#car#drivers, lap#driverName) | build#car };
        let newLap1 = match build#lap1Elapsed {
            case Some(_) => build#lap1Elapsed
            case None    => lap1Elapsed(lap)
        };
        { car = updatedCar, lap1Elapsed = newLap1 }

    def lap1Elapsed(lap: RawLap): Option[Int32] =
        if (lap#lapNumber == 1) Duration.toMillis(lap#elapsed)
        else None

    def appendUnique(xs: List[String], x: String): List[String] =
        if (List.exists(s -> s == x, xs)) xs
        else List.append(xs, x :: Nil)

    def assignStartPositions(builds: List[CarBuild]): List[StartingGrid] =
        let withLap1 = builds |> List.filterMap(b ->
            match b#lap1Elapsed {
                case Some(ms) => Some((b#car#carNumber, ms))
                case None     => None
            }
        );
        let sorted = List.sortBy(p -> match p { case (_, ms) => ms }, withLap1);
        let positions = List.map(p -> match p { case (i, (cn, _)) => (cn, i) }, withIndex(sorted));
        builds |> List.map(b ->
            let pos = match List.find(p -> match p { case (cn, _) => cn == b#car#carNumber }, positions) {
                case Some((_, p)) => p
                case None         => 0
            };
            { position = pos, car = b#car }
        )

    def withIndex(xs: List[a]): List[(Int32, a)] =
        let step = (state, x) -> match state { case (acc, i) => ((i, x) :: acc, i + 1) };
        let (result, _) = List.foldLeft(step, (Nil, 0), xs);
        List.reverse(result)

    pub def toJson(meta: Metadata): Json.JsonValue =
        JsonObject(
            ("name",         JsonString(meta#name)) ::
            ("startingGrid", JsonArray(meta#startingGrid |> List.map(toGridEntryJson))) ::
            Nil
        )

    def toGridEntryJson(entry: StartingGrid): Json.JsonValue =
        JsonObject(
            ("position", JsonInt(entry#position)) ::
            ("car",      carToJson(entry#car)) ::
            Nil
        )

    def carToJson(car: Car): Json.JsonValue =
        JsonObject(
            ("carNumber",    JsonString(car#carNumber)) ::
            ("drivers",      JsonArray(car#drivers |> List.map(driverToJson))) ::
            ("class",        JsonString(car#class)) ::
            ("group",        JsonString(car#group)) ::
            ("team",         JsonString(car#team)) ::
            ("manufacturer", JsonString(car#manufacturer)) ::
            Nil
        )

    def driverToJson(name: String): Json.JsonValue =
        JsonObject(("name", JsonString(name)) :: Nil)

}
