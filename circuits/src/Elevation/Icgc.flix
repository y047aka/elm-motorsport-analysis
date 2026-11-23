/// The Institut Cartogràfic i Geològic de Catalunya's terrain model at 2 m (MET-2), from
/// its LiDAR survey: Catalonia alone.
///
/// The model is served as a WMS and as nothing a place can be asked of directly, so a
/// place is asked by `GetFeatureInfo` at the middle pixel of a map drawn round it, one
/// place per request, and comes back as a line of text: `@MET2m Stretch.Pixel Value;
/// 120.430000;`. A place outside Catalonia is answered 400.
pub mod Elevation.Icgc {

    use Geodesy.Place
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https

    pub def service(): String =
        "https://geoserveis.icgc.cat/icgc_mdt2m/wms/service"

    pub def resolution(): Float64 = 2.0

    pub def sample(places: List[Place]): Result[String, List[Elevation.Sample]] \ { IO, Https } =
        places
            |> Result.traverse(at -> Elevation.sentHolding(HttpRequest.get(urlOf(at)), "ICGC MET-2", "Pixel Value") |> Result.flatMap(sampleOf(at)))

    /// A map 101 pixels square, a thousandth of a degree across, centred on the place: its
    /// middle pixel, the 51st, is the one whose centre stands at the place. WMS 1.3.0 lays
    /// EPSG:4326 latitude first.
    pub def urlOf(at: Place): String =
        let n = Geometry.Write.number;
        let half = 0.0005;
        "${service()}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=MET2m&QUERY_LAYERS=MET2m&CRS=EPSG:4326&BBOX=${n(at#lat - half)},${n(at#lon - half)},${n(at#lat + half)},${n(at#lon + half)}&WIDTH=101&HEIGHT=101&I=50&J=50&INFO_FORMAT=text/plain&STYLES="

    pub def sampleOf(at: Place, text: String): Result[String, Elevation.Sample] =
        match String.splitOn({substr = ";"}, text) |> List.map(String.trim) {
            case _ :: value :: _ =>
                match Float64.fromString(value) {
                    case Some(height) => Ok({place = at, metres = height, resolution = resolution()})
                    case None         => Err("ICGC MET-2 holds no height at ${Geometry.Write.coordinate(at#lon, at#lat)}")
                }
            case _ => Err("ICGC MET-2 holds no height at ${Geometry.Write.coordinate(at#lon, at#lat)}")
        }
}
