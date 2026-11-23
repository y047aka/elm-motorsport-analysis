/// The USGS 3D Elevation Program, asked through its ImageServer's `getSamples`: the
/// heights of the best-available bare-earth model at each place, which at COTA is a
/// 1 m LiDAR survey. It covers the United States alone.
///
/// One request carries a multipoint of up to `batch` places and comes back with one
/// sample per place, matched to it by `locationId`, the index it was sent at. A height
/// comes as a string, and as `NoData` where the model holds none.
pub mod Elevation.Usgs {

    use Geodesy.Place
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https
    use Util.Json.Json

    pub def dataset(): Elevation.Dataset = {
        name    = "USGS 3D Elevation Program (3DEP), best available",
        license = "public domain",
        datum   = "NAVD88",
        service = "https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer"
    }

    /// Places per request.
    pub def batch(): Int32 = 200

    /// How many times a batch is asked before the run gives up: the service answers 504
    /// for minutes at a time.
    pub def tries(): Int32 = 3

    /// Every place sampled, a batch at a time, in the order the places were given.
    pub def sample(places: List[Place]): Result[String, List[Elevation.Sample]] \ { IO, Https } =
        batches(places)
            |> Result.traverse(some -> asked(some, 1) |> Result.flatMap(samplesOf(some)))
            |> Result.map(List.flatten)

    def asked(places: List[Place], attempt: Int32): Result[String, String] \ { IO, Https } =
        match Service.send(request(places), "USGS 3DEP") {
            case Ok(text) => Ok(text)
            case Err(problem) =>
                if (attempt >= tries())
                    Err(problem)
                else {
                    Net.HttpLayer.sleep(Time.Duration.toMillis(Overpass.backoff(attempt)));
                    asked(places, attempt + 1)
                }
        }

    def batches(places: List[Place]): List[List[Place]] =
        if (List.isEmpty(places))
            Nil
        else
            List.take(batch(), places) :: batches(List.drop(batch(), places))

    def request(places: List[Place]): HttpRequest =
        HttpRequest.postWith("${dataset()#service}/getSamples", form(places))
            |> HttpRequest.withHeader("Content-Type", "application/x-www-form-urlencoded")

    /// The form one batch is asked with. The degrees are spelled as the geometry file
    /// spells them, so a place is asked at exactly the degrees it is kept under.
    pub def form(places: List[Place]): String =
        let points = places |> List.map(at -> Geometry.Write.coordinate(at#lon, at#lat)) |> String.intercalate(",");
        let geometry = "{\"points\":[${points}],\"spatialReference\":{\"wkid\":4326}}";
        "geometry=${Net.HttpLayer.urlEncode(geometry)}&geometryType=esriGeometryMultipoint&returnFirstValueOnly=true&interpolation=RSP_BilinearInterpolation&f=json"

    /// One batch's answer, read against the places it was asked for: a sample for every
    /// place, or the sentence naming the first that has none. ArcGIS answers a request
    /// it refuses as 200 with an `error` member.
    pub def samplesOf(places: List[Place], text: String): Result[String, List[Elevation.Sample]] =
        match Util.Json.parse(text) {
            case Err(problem) => Err("USGS 3DEP: ${problem}")
            case Ok(Json.JObject(root)) =>
                match (Map.get("error", root), Map.get("samples", root)) {
                    case (Some(error), _) => Err("USGS 3DEP refused the request: ${Util.Json.toCompactString(error)}")
                    case (None, Some(Json.JArray(items))) =>
                        Vector.toList(items)
                            |> Result.traverse(sampleOf)
                            |> Result.flatMap(read -> matched(places, List.toMap(read), 0))
                    case _ => Err("USGS 3DEP answered no samples")
                }
            case Ok(_) => Err("USGS 3DEP answered no samples")
        }

    /// One sample: the index it was asked at, and its height and resolution where the
    /// model holds one.
    def sampleOf(json: Json): Result[String, (Int32, Option[(Float64, Float64)])] =
        match json {
            case Json.JObject(members) =>
                let at = Map.get("locationId", members) |> Option.flatMap(whole);
                let height = match Map.get("value", members) {
                    case Some(Json.JString(spelled)) => Float64.fromString(spelled)
                    case _                           => None
                };
                let resolution = Map.get("resolution", members) |> Option.flatMap(Geometry.number);
                match at {
                    case None     => Err("USGS 3DEP answered a sample with no locationId")
                    case Some(id) => Ok((id, Option.flatMap(h -> Option.map(r -> (h, r), resolution), height)))
                }
            case _ => Err("USGS 3DEP answered a sample that is no object")
        }

    def whole(json: Json): Option[Int32] =
        match json {
            case Json.JNumber(spelled) => Int32.fromString(BigDecimal.toPlainString(spelled))
            case _                     => None
        }

    def matched(places: List[Place], read: Map[Int32, Option[(Float64, Float64)]], at: Int32): Result[String, List[Elevation.Sample]] =
        match places {
            case Nil => Ok(Nil)
            case place :: more =>
                match Map.get(at, read) {
                    case Some(Some((height, resolution))) =>
                        matched(more, read, at + 1)
                            |> Result.map(rest -> {place = place, metres = height, resolution = resolution} :: rest)
                    case Some(None) => Err("USGS 3DEP holds no height at ${Geometry.Write.coordinate(place#lon, place#lat)}")
                    case None       => Err("USGS 3DEP answered no sample for ${Geometry.Write.coordinate(place#lon, place#lat)}")
                }
        }
}
