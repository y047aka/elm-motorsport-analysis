/// The rounds, served rather than exported. An endpoint answers with what
/// `Cli.Export` writes to a file, byte for byte.
mod Server.Api {

    use Round.Index
    use Round.Laps
    use Round.Render
    use Round.Summary
    use Motorsport.Calendar
    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Util.Json.Encode.Extra

    /// `cause` is what went wrong, for the log rather than for the answer: a
    /// failure says what it says in the database's words, which name tables
    /// and files the caller was not offered.
    pub type alias Response = {
        status = Int32,
        contentType = String,
        body = String,
        cause = Option[String]
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

    pub def respond(route: Route): Response \ SqlRead =
        match route {
            case Route.Health            => ok("text/plain", "ok")
            case Route.Calendar          => ok("application/json", calendar())
            case Route.Summary(year, id) => body("application/json", () -> summary(year, id))
            case Route.Laps(year, id)    => body("application/jsonl", () -> laps(year, id))
            case Route.NotFound          => notFound("not found")
        }

    def ok(contentType: String, body: String): Response =
        { status = 200, contentType = contentType, body = body, cause = None }

    def notFound(reason: String): Response =
        { status = 404, contentType = "text/plain", body = reason, cause = None }

    def body(contentType: String, render: Unit -> Option[String] \ ef): Response \ (ef - DbErr) =
        match Db.runWithError(render) {
            case Ok(Some(rendered)) => ok(contentType, rendered)
            case Ok(None)           => notFound("round not loaded")
            case Err(cause)         => failed(cause)
        }

    /// 503 rather than 500 where the database was not reached or was busy:
    /// the round can be served, and not now.
    def failed(cause: Db.Error): Response =
        let (status, reason) = match cause {
            case Db.Error.Unreachable(_) => (503, "the database could not be reached")
            case Db.Error.Busy(_)        => (503, "the database is busy")
            case _                       => (500, "the round could not be read")
        };
        { status = status, contentType = "text/plain", body = reason, cause = Some("${cause}") }

    def calendar(): String =
        Extra.render(Manifest.toJson(urlRoot(), Calendar.seasons()))

    def summary(season: Int32, id: String): Option[String] \ DbRead =
        answer(season, id, e -> Render.renderSummary(Summary.read(e), Index.read(e)))

    def laps(season: Int32, id: String): Option[String] \ DbRead =
        answer(season, id, e -> Render.renderJsonl(Laps.read(e)))

    /// `None` is a round no answer is served for: one the calendar does not
    /// list, and one it lists that no run has loaded. Rendered out of the rows
    /// the second would be a race that never ran, which is the one thing they
    /// cannot say for themselves.
    def answer(season: Int32, id: String, render: Entry -> String \ DbRead): Option[String] \ DbRead =
        match Calendar.find(season, id) {
            case None        => None
            case Some(round) => if (Round.loaded(round)) Some(render(round)) else None
        }

}
