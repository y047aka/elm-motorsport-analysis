/// メタデータ JSON (`{stem}.json`) のドメインモデルとレンダラ。
/// Rust 版 `cli::stages::output::MetadataOutput` (cli/src/stages/output.rs
/// L61-112) と `cli::stages::transform::build_cars` / `start_positions`
/// (transform.rs L46-74, L212-233) を 1 モジュールに合体させたもの。
mod Metadata {

    use Json.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Car.Car
    use RawLap.RawLap

    pub type alias Metadata = {
        name         = String,
        startingGrid = List[Car]
    }

    /// CSV 行から作った `RawLap[]` と event id から `Metadata` を組み立てる。
    pub def fromRawLaps(eventId: String, rawLaps: List[RawLap]): Metadata =
        let cars = buildCars(rawLaps);
        let withPositions = assignStartPositions(cars);
        {
            name         = Events.displayName(eventId),
            startingGrid = withPositions
        }

    /// CSV 出現順を保ったまま `RawLap[]` を `Car[]` に集約する。
    /// 同じ `carNumber` の追加ラップは drivers と lap1Elapsed を更新する。
    def buildCars(rawLaps: List[RawLap]): List[Car] =
        rawLaps |> List.foldLeft((acc, lap) -> upsertCar(acc, lap), Nil)

    def upsertCar(acc: List[Car], lap: RawLap): List[Car] =
        if (List.exists(c -> c#carNumber == lap#carNumber, acc))
            acc |> List.map(c ->
                if (c#carNumber == lap#carNumber) updateCarWithLap(c, lap) else c
            )
        else
            List.append(acc, carFromLap(lap) :: Nil)

    def carFromLap(lap: RawLap): Car =
        {
            carNumber     = lap#carNumber,
            drivers       = lap#driverName :: Nil,
            class         = lap#class,
            group         = lap#group,
            team          = lap#team,
            manufacturer  = lap#manufacturer,
            lap1Elapsed   = lap1Elapsed(lap),
            startPosition = 0
        }

    def updateCarWithLap(car: Car, lap: RawLap): Car =
        let newDrivers = appendUnique(car#drivers, lap#driverName);
        let newLap1 = match car#lap1Elapsed {
            case Some(_) => car#lap1Elapsed
            case None    => lap1Elapsed(lap)
        };
        { drivers = newDrivers, lap1Elapsed = newLap1 | car }

    def lap1Elapsed(lap: RawLap): Option[Int32] =
        if (lap#lapNumber == 1) Duration.toMillis(lap#elapsed)
        else None

    def appendUnique(xs: List[String], x: String): List[String] =
        if (List.exists(s -> s == x, xs)) xs
        else List.append(xs, x :: Nil)

    /// ラップ1 の elapsed (ms) で 0-based 順位を割り当てる。
    /// ラップ1 が無い車は `startPosition = 0` のまま (Rust transform.rs L224-232 と同挙動)。
    def assignStartPositions(cars: List[Car]): List[Car] =
        let withLap1 = cars |> List.filterMap(c ->
            match c#lap1Elapsed {
                case Some(ms) => Some((c#carNumber, ms))
                case None     => None
            }
        );
        let sorted = withLap1 |> List.sortBy(match (_, ms) -> ms);
        let positions = withIndex(sorted) |> List.map(match (i, (cn, _)) -> (cn, i));
        cars |> List.map(c ->
            match List.find(match (cn, _) -> cn == c#carNumber, positions) {
                case Some((_, p)) => { startPosition = p | c }
                case None         => c
            }
        )

    def withIndex(xs: List[a]): List[(Int32, a)] =
        let (result, _) = List.foldLeft(
            match ((acc, i), x) -> ((i, x) :: acc, i + 1),
            (Nil, 0),
            xs
        );
        List.reverse(result)

    /// メタデータを JSON (Rust `serde_json` 構造体宣言順と同じキー順) に変換。
    pub def toJson(meta: Metadata): Json.JsonValue =
        JsonObject(
            ("name",         JsonString(meta#name)) ::
            ("startingGrid", JsonArray(meta#startingGrid |> List.map(toGridEntry))) ::
            Nil
        )

    def toGridEntry(car: Car): Json.JsonValue =
        JsonObject(
            ("position", JsonInt(car#startPosition)) ::
            ("car",      carToJson(car)) ::
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
