/// The rounds, served rather than exported. What an endpoint answers with is
/// what `Cli.Stages` writes to a file: the same summary, and the same laps in
/// the same order, so a reader cannot tell the two apart.
mod Cli.Api {

    use Cli.Db
    use Cli.Db.LapRow
    use Cli.Db.Schema
    use Cli.Stages.Manifest
    use Cli.Stages.Summary
    use Cli.Stages.Transform
    use Motorsport.Calendar
    use Motorsport.Calendar.Entry
    use Motorsport.Metadata
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

    /// The calendar is what says a round exists, here as in the export: a round
    /// it does not list has no rows to read and no path to reach them by.
    def listed(season: Int32, id: String, found: Route): Route =
        match Calendar.find(season, id) {
            case Some(_) => found
            case None    => Route.NotFound
        }

    /// The calendar is `Motorsport.Calendar`, written down rather than counted
    /// out of the rows, and health is the process answering at all. Neither is
    /// a reason to need a database that a round is.
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
            case Route.NotFound          => { status = 404, contentType = "text/plain", body = "not found" }
        }

    def ok(contentType: String, body: String): Response =
        { status = 200, contentType = contentType, body = body }

    def body(contentType: String, result: Result[String, String]): Response =
        match result {
            case Ok(rendered) => ok(contentType, rendered)
            case Err(cause)   => { status = 500, contentType = "text/plain", body = cause }
        }

    def calendar(): String =
        Extra.render(Manifest.toJson(urlRoot(), Calendar.seasons()))

    def summary(season: Int32, id: String): Result[String, String] \ Db =
        entry(season, id)
            |> Result.flatMap(Summary.read)
            |> Result.map(metadata -> Extra.render(Metadata.toJson(metadata)))

    def laps(season: Int32, id: String): Result[String, String] \ Db =
        forM(
            _       <- entry(season, id);
            rows    <- Db.fetch(Schema.selectRound(season, id));
            lapRows <- Result.traverse(LapRow.fromRow, rows);
            rawLaps <- Result.traverse(LapRow.toRawLap, lapRows)
        ) yield Transform.renderJsonl(rawLaps)

    def entry(season: Int32, id: String): Result[String, Entry] =
        Calendar.find(season, id)
            |> Option.toOk("no round ${id} in ${season}")

}
