/// The asking of a service over HTTPS, written once for every service this project asks:
/// OpenStreetMap's runners and the elevation services a survey's places are sampled from.
///
/// This is the name a run calls itself by, the pace between its requests, and the one
/// reading of what a service *answered with*. What each service is asked is its own
/// module's: `Overpass` walks its runners, `Elevation` its sources.
pub mod Service {

    use IoError.IoError
    use Net.HttpRequest.HttpRequest
    use Net.HttpResponse.HttpResponse
    use Net.Https.Https
    use Time.Clock
    use Time.Duration

    /// What a run calls itself. A service's operator reads a log, and an anonymous
    /// request is a request nobody can tell from a flood.
    pub def userAgent(): String = "elm-motorsport-analysis/1.0 (circuit geometry)"

    /// The shortest interval between two requests of one run.
    pub def pace(): Duration = Duration.of(1500, Time.TimeUnit.Milliseconds)

    /// The handlers one run asks through: the User-Agent every request carries, the
    /// pace between them, and the client underneath.
    pub def paced(asking: Unit -> a \ ef): a \ (ef - Https) + { IO, Clock } =
        Net.Https.runWithIO(() ->
            Net.Https.withDefaultHeaders(headers(), () ->
                Net.Https.withMinInterval({interval = pace()}, () -> asking())
            )
        )

    def headers(): Map[String, List[String]] =
        Map.insert("User-Agent", userAgent() :: Nil, Map.empty())

    /// One request sent, and what came back read: `asked` is who a failure names.
    pub def send(request: HttpRequest, asked: String): Result[String, String] \ Https =
        sendFor(request, asked, body -> kept(body, asked))

    /// One request sent to a service that answers in something other than JSON, and its
    /// body kept only where it holds `holding`: the HTML page a proxy answers with holds
    /// no such word.
    pub def sendHolding(request: HttpRequest, asked: String, holding: String): Result[String, String] \ Https =
        sendFor(request, asked, body ->
            if (String.contains({substr = holding}, body)) Ok(body)
            else Err("${asked} answered with something that holds no ${holding}")
        )

    def sendFor(request: HttpRequest, asked: String, read: String -> Result[String, String]): Result[String, String] \ Https =
        match Https.send(request) {
            case Err(error)   => Err(worded(error))
            case Ok(response) => answered(response, asked, read)
        }

    /// A response, read: the body a service sent when it answered in JSON, or the sentence
    /// it answered with. Two things make a body no answer — a status that is no success,
    /// and text that is no JSON — and only the first of them is in the status: a service
    /// behind a proxy answers a request it let time out as 200 with an HTML page.
    def answered(response: HttpResponse, asked: String, read: String -> Result[String, String]): Result[String, String] =
        if (not Net.HttpResponse.isSuccess(response))
            Err("${asked} answered ${Net.HttpResponse.status(response)}")
        else
            read(Net.HttpResponse.body(response))

    /// A transport failure as the report prints it: which kind, and what the client
    /// said about it.
    def worded(error: IoError): String = match error {
        case IoError(kind, message) => "${kind}: ${message}"
    }

    /// A body as it is kept, if it is an answer at all: that it opens as JSON is the
    /// first thing asked of it, before its contents, which are the asking module's to
    /// read. The refusal names whoever was asked.
    pub def kept(text: String, asked: String): Result[String, String] =
        if (String.startsWith({prefix = "{"}, text) or String.startsWith({prefix = "["}, text))
            Ok(text)
        else
            Err("${asked} answered with something that is not JSON")
}
