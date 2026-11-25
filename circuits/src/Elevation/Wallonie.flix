/// The Service public de Wallonie's terrain model at 0.5 m (MNT 2021-2022), from its LiDAR
/// survey: Wallonia alone.
///
/// The model is served as an ArcGIS MapServer and as no ImageServer, so a place is asked by
/// `identify` at the place itself, one place per request, and comes back as the pixel it
/// stands in: `{"results":[{..., "attributes":{"Stretch.Pixel Value":"414.223145"}}]}`. A
/// place outside Wallonia comes back as `{"results":[]}`.
pub mod Elevation.Wallonie {

    use Geodesy.Place
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https
    use Util.Json.Json

    pub def service(): String =
        "https://geoservices.wallonie.be/arcgis/rest/services/RELIEF/WALLONIE_MNT_2021_2022/MapServer"

    pub def resolution(): Float64 = 0.5

    pub def sample(places: List[Place]): Result[String, List[Elevation.Sample]] \ { IO, Https } =
        places
            |> Result.traverse(at -> Elevation.sent(HttpRequest.get(urlOf(at)), "SPW MNT 2021-2022") |> Result.flatMap(sampleOf(at)))

    /// `identify` reads the map it would be drawn on as well as the place: a map a
    /// thousandth of a degree across, centred on the place, with no tolerance, answers the
    /// one pixel the place stands in.
    pub def urlOf(at: Place): String =
        let n = Geometry.Write.number;
        let half = 0.0005;
        "${service()}/identify?geometry=${n(at#lon)},${n(at#lat)}&geometryType=esriGeometryPoint&sr=4326&layers=all:0&tolerance=0&mapExtent=${n(at#lon - half)},${n(at#lat - half)},${n(at#lon + half)},${n(at#lat + half)}&imageDisplay=101,101,96&returnGeometry=false&f=json"

    pub def sampleOf(at: Place, text: String): Result[String, Elevation.Sample] =
        let nowhere = "SPW MNT 2021-2022 holds no height at ${Geometry.Write.coordinate(at#lon, at#lat)}";
        match Util.Json.parse(text) {
            case Ok(Json.JObject(root)) =>
                match Map.get("results", root) {
                    case Some(Json.JArray(results)) =>
                        match Vector.toList(results) {
                            case Json.JObject(result) :: _ =>
                                match Map.get("attributes", result) {
                                    case Some(Json.JObject(attributes)) =>
                                        match Geometry.word("Stretch.Pixel Value", attributes) |> Option.flatMap(Float64.fromString) {
                                            case Some(height) => Ok({place = at, metres = height, resolution = resolution()})
                                            case None         => Err(nowhere)
                                        }
                                    case _ => Err(nowhere)
                                }
                            case _ => Err(nowhere)
                        }
                    case _ => Err("SPW MNT 2021-2022 answered no results")
                }
            case Ok(_)        => Err("SPW MNT 2021-2022 answered no results")
            case Err(problem) => Err("SPW MNT 2021-2022: ${problem}")
        }
}
