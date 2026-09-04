/// The rounds, served rather than exported. An endpoint answers with what
/// `Cli.Export` writes to a file, byte for byte.
mod Server.Api {

    use Round.Laps
    use Round.Render
    use Round.Summary
    use Motorsport.Calendar
    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Util.Json.Encode.Extra

    pub type alias Response = {
        status = Int32,
        contentType = String,
        body = String
    }

    pub enum Route with Eq, ToString {
        case Health
        case Calendar
        case Summary(Int32, String)
        case Laps(Int32, String)
        case NotFound
    }

    /// Where the app reads the rounds from, as `/static/wec` is where it reads
    /// the exported files from. A round is named here the way the export names
    /// its files, so one path is the other with its root replaced.
    pub def urlRoot(): String = "/api/wec"

    pub def route(path: String): Route =
        match String.splitOn({substr = "/"}, path) {
            case "" :: "api" :: "health" :: Nil => Route.Health
            case "" :: "api" :: "wec" :: "index.json" :: Nil => Route.Calendar
            case "" :: "api" :: "wec" :: season :: file :: Nil => roundRoute(season, file)
            case _ => Route.NotFound
        }

    def roundRoute(season: String, file: String): Route =
        match Int32.fromString(season) {
            case None => Route.NotFound
            case Some(year) =>
                match (String.stripSuffix({substr = "_laps.jsonl"}, file), String.stripSuffix({substr = ".json"}, file)) {
                    case (Some(id), _) => listed(year, id, Route.Laps(year, id))
                    case (_, Some(id)) => listed(year, id, Route.Summary(year, id))
                    case _             => Route.NotFound
                }
        }

    def listed(season: Int32, id: String, found: Route): Route =
        match Calendar.find(season, id) {
            case Some(_) => found
            case None    => Route.NotFound
        }

    /// The calendar is `Motorsport.Calendar`, not a count of the rows.
    pub def needsDatabase(route: Route): Bool =
        match route {
            case Route.Summary(_, _) => true
            case Route.Laps(_, _)    => true
            case _                   => false
        }

    pub def respond(route: Route): Response \ Db =
        match route {
            case Route.Health            => ok("text/plain", "ok")
            case Route.Calendar          => ok("application/json", calendar())
            case Route.Summary(year, id) => body("application/json", summary(year, id))
            case Route.Laps(year, id)    => body("application/jsonl", laps(year, id))
            case Route.NotFound          => notFound("not found")
        }

    def ok(contentType: String, body: String): Response =
        { status = 200, contentType = contentType, body = body }

    def notFound(reason: String): Response =
        { status = 404, contentType = "text/plain", body = reason }

    def body(contentType: String, result: Result[String, Option[String]]): Response =
        match result {
            case Ok(Some(rendered)) => ok(contentType, rendered)
            case Ok(None)           => notFound("round not loaded")
            case Err(cause)         => { status = 500, contentType = "text/plain", body = cause }
        }

    def calendar(): String =
        Extra.render(Manifest.toJson(urlRoot(), Calendar.seasons()))

    def summary(season: Int32, id: String): Result[String, Option[String]] \ Db =
        answer(season, id, e -> Summary.read(e) |> Result.map(Render.renderMetadata))

    def laps(season: Int32, id: String): Result[String, Option[String]] \ Db =
        answer(season, id, e -> Laps.read(e) |> Result.map(Render.renderJsonl))

    /// `None` is a round the calendar lists and no run has loaded. Rendered
    /// out of the rows it would be a race that never ran, which is the one
    /// thing they cannot say for themselves.
    def answer(season: Int32, id: String, render: Entry -> Result[String, String] \ Db): Result[String, Option[String]] \ Db =
        forM(
            round    <- entry(season, id);
            isLoaded <- Laps.loaded(round);
            rendered <- if (isLoaded) Result.map(Some, render(round)) else Ok(None)
        ) yield rendered

    def entry(season: Int32, id: String): Result[String, Entry] =
        Calendar.find(season, id)
            |> Option.toOk("no round ${id} in ${season}")

}
