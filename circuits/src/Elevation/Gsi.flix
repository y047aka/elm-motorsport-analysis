/// The Geospatial Information Authority of Japan's elevation API: the height of its best
/// model at one place per request — at Fuji, a 1 m laser survey — and which model that
/// was, as `hsrc` (`1m（レーザ）`, `5m（写真測量）`, ...). A place it holds nothing for comes
/// back as `-----`.
pub mod Elevation.Gsi {

    use Geodesy.Place
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https
    use Util.Json.Json

    pub def service(): String =
        "https://cyberjapandata2.gsi.go.jp/general/dem/scripts/getelevation.php"

    pub def sample(places: List[Place]): Result[String, List[Elevation.Sample]] \ { IO, Https } =
        places
            |> Result.traverse(at -> Elevation.sent(HttpRequest.get(urlOf(at)), "GSI elevation") |> Result.flatMap(sampleOf(at)))

    pub def urlOf(at: Place): String =
        "${service()}?lon=${Geometry.Write.number(at#lon)}&lat=${Geometry.Write.number(at#lat)}&outtype=JSON"

    pub def sampleOf(at: Place, text: String): Result[String, Elevation.Sample] =
        match Util.Json.parse(text) {
            case Ok(Json.JObject(root)) =>
                match (Map.get("elevation", root) |> Option.flatMap(Geometry.number), Geometry.word("hsrc", root)) {
                    case (Some(height), Some(model)) => Ok({place = at, metres = height, resolution = resolutionOf(model)})
                    case _ => Err("GSI elevation holds no height at ${Geometry.Write.coordinate(at#lon, at#lat)}")
                }
            case Ok(_)        => Err("GSI elevation answered no elevation")
            case Err(problem) => Err("GSI elevation: ${problem}")
        }

    /// The metres a model's name opens with: `5m（レーザ）` is 5, `0.2m...` is 0.2.
    def resolutionOf(model: String): Float64 =
        model
            |> String.takeWhile(c -> Char.isDigit(c) or c == '.')
            |> Float64.fromString
            |> Option.getWithDefault(0.0)
}
