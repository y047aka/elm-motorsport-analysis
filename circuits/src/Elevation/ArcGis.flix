/// An ArcGIS ImageServer asked through its `getSamples`: the height of an elevation model
/// at each place. USGS 3DEP, Regione Lombardia's DTM 5x5 and Regione Emilia-Romagna's DTM
/// 2022 are all served this way.
///
/// One request carries a multipoint of up to `batch` places and comes back with one
/// sample per place, matched to it by `locationId`, the index it was sent at. A height
/// comes as a string, and as `NoData` where the model holds none.
pub mod Elevation.ArcGis {

    use Geodesy.Place
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https
    use Util.Json.Json

    /// Places per request.
    pub def batch(): Int32 = 200

    /// Every place sampled off the image server at `service`, a batch at a time, in the
    /// order the places were given. `who` is the name a failure is said in.
    pub def sample(service: String, who: String, places: List[Place]): Result[String, List[Elevation.Sample]] \ { IO, Https } =
        Elevation.batches(batch(), places)
            |> Result.traverse(some -> Elevation.sent(request(service, some), who) |> Result.flatMap(samplesOf(who, some)))
            |> Result.map(List.flatten)

    def request(service: String, places: List[Place]): HttpRequest =
        HttpRequest.postWith("${service}/getSamples", form(places))
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
    pub def samplesOf(who: String, places: List[Place], text: String): Result[String, List[Elevation.Sample]] =
        match Util.Json.parse(text) {
            case Err(problem) => Err("${who}: ${problem}")
            case Ok(Json.JObject(root)) =>
                match (Map.get("error", root), Map.get("samples", root)) {
                    case (Some(error), _) => Err("${who} refused the request: ${Util.Json.toCompactString(error)}")
                    case (None, Some(Json.JArray(items))) =>
                        Vector.toList(items)
                            |> Result.traverse(sampleOf(who))
                            |> Result.flatMap(read -> matched(who, places, List.toMap(read), 0))
                    case _ => Err("${who} answered no samples")
                }
            case Ok(_) => Err("${who} answered no samples")
        }

    /// One sample: the index it was asked at, and its height and resolution where the
    /// model holds one. A resolution the service leaves out is nought, an unknown one,
    /// rather than a place with no height.
    def sampleOf(who: String, json: Json): Result[String, (Int32, Option[(Float64, Float64)])] =
        match json {
            case Json.JObject(members) =>
                let at = Map.get("locationId", members) |> Option.flatMap(whole);
                let height = match Map.get("value", members) {
                    case Some(Json.JString(spelled)) => Float64.fromString(spelled)
                    case _                           => None
                };
                let resolution = Map.get("resolution", members) |> Option.flatMap(Geometry.number) |> Option.getWithDefault(0.0);
                match at {
                    case None     => Err("${who} answered a sample with no locationId")
                    case Some(id) => Ok((id, Option.map(h -> (h, resolution), height)))
                }
            case _ => Err("${who} answered a sample that is no object")
        }

    def whole(json: Json): Option[Int32] =
        match json {
            case Json.JNumber(spelled) => Int32.fromString(BigDecimal.toPlainString(spelled))
            case _                     => None
        }

    def matched(who: String, places: List[Place], read: Map[Int32, Option[(Float64, Float64)]], at: Int32): Result[String, List[Elevation.Sample]] =
        match places {
            case Nil => Ok(Nil)
            case place :: more =>
                match Map.get(at, read) {
                    case Some(Some((height, resolution))) =>
                        matched(who, more, read, at + 1)
                            |> Result.map(rest -> {place = place, metres = height, resolution = resolution} :: rest)
                    case Some(None) => Err("${who} holds no height at ${Geometry.Write.coordinate(place#lon, place#lat)}")
                    case None       => Err("${who} answered no sample for ${Geometry.Write.coordinate(place#lon, place#lat)}")
                }
        }
}
