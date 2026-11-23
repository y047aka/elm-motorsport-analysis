/// The IGN's Géoplateforme altimetry service, asked for the heights of its LiDAR HD
/// bare-earth model: France alone, at half a metre.
///
/// One request names up to `batch` places in its query, longitudes and latitudes each
/// joined by `|`, and comes back with one height per place in the order they were named.
/// A place the model holds nothing for comes back as -99999.
pub mod Elevation.Geopf {

    use Geodesy.Place
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https
    use Util.Json.Json

    pub def service(): String =
        "https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json"

    /// The model asked of the service: LiDAR HD's terrain, its holes filled by
    /// interpolation, since a hole under a car park is a place no height is drawn at.
    pub def resource(): String = "ign_lidar_hd_mnt_mono_wld"

    /// The model's resolution, which the service does not answer with.
    pub def resolution(): Float64 = 0.5

    /// Places per request; their degrees travel in the URL.
    pub def batch(): Int32 = 100

    pub def sample(places: List[Place]): Result[String, List[Elevation.Sample]] \ { IO, Https } =
        Elevation.batches(batch(), places)
            |> Result.traverse(some -> Elevation.sent(HttpRequest.get(urlOf(some)), "IGN altimetry") |> Result.flatMap(samplesOf(some)))
            |> Result.map(List.flatten)

    pub def urlOf(places: List[Place]): String =
        let joined = f -> places |> List.map(at -> Geometry.Write.number(f(at))) |> String.intercalate("|") |> Net.HttpLayer.urlEncode;
        "${service()}?lon=${joined(at -> at#lon)}&lat=${joined(at -> at#lat)}&resource=${resource()}&zonly=true"

    pub def samplesOf(places: List[Place], text: String): Result[String, List[Elevation.Sample]] =
        match Util.Json.parse(text) {
            case Ok(Json.JObject(root)) =>
                match Map.get("elevations", root) {
                    case Some(Json.JArray(items)) =>
                        let heights = Vector.toList(items) |> List.map(Geometry.number);
                        if (List.length(heights) != List.length(places))
                            Err("IGN altimetry gave ${List.length(heights)} heights for ${List.length(places)} places")
                        else
                            List.zip(places, heights) |> Result.traverse(pair -> match pair {
                                case (at, Some(height)) if height > -1000.0 => Ok({place = at, metres = height, resolution = resolution()})
                                case (at, _) => Err("IGN altimetry holds no height at ${Geometry.Write.coordinate(at#lon, at#lat)}")
                            })
                    case _ => Err("IGN altimetry answered no elevations")
                }
            case Ok(_)        => Err("IGN altimetry answered no elevations")
            case Err(problem) => Err("IGN altimetry: ${problem}")
        }
}
