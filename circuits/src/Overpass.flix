/// The asking of OpenStreetMap, written once and asked two questions: the survey's,
/// which a kept geometry is drawn from, and the probe's, which decides — before a
/// circuit has a config — which relation a circuit is.
///
/// Two runners answer one query because a busy one answers 502 or 504. Each runner
/// is asked twice, and a runner that failed is left alone longer each time, so
/// that a run outlasts a runner's moment of being busy.
///
/// What is asked is `Overpass.Query`'s and what comes back is `Overpass.Answer`'s; this
/// module is the walking of the runners, the pace between the asks, and the one reading
/// of what a service *answered with*. The atlas reading asks another service — a
/// dataset's repository, once, with no list of runners to walk down — and reads its
/// response here, so what an answer is is one reading for both services.
///
/// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; an answer read
/// here is a derivative of their tags.
pub mod Overpass {

    use IoError.IoError
    use Net.HttpRequest.HttpRequest
    use Net.HttpResponse.HttpResponse
    use Net.Https.Https
    use Overpass.Answer.Answer
    use Time.Clock
    use Time.Duration

    /// Each runner, in the order a run walks them. The first answers slowly when
    /// everyone else does too; the second answers the same query off another machine.
    pub def runners(): List[String] =
        "https://overpass-api.de/api/interpreter" ::
        "https://overpass.kumi.systems/api/interpreter" :: Nil

    /// How many times each runner is asked before the walk gives up on it.
    pub def tries(): Int32 = 2

    /// What a run calls itself. A runner's operator reads a log, and an anonymous
    /// request is a request nobody can tell from a flood.
    pub def userAgent(): String = "elm-motorsport-analysis/1.0 (circuit geometry)"

    /// The shortest interval between two requests of one run.
    pub def pace(): Duration = Duration.of(1500, Time.TimeUnit.Milliseconds)

    /// How long a runner that just failed is left alone for, longer each time that
    /// same runner is asked again.
    pub def backoff(attempt: Int32): Duration = Duration.of(4000 * attempt, Time.TimeUnit.Milliseconds)

    // ------------------------------------------------------------------- the asking

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

    /// One query, asked. When every runner has failed the failure carries the last
    /// thing any of them said, which is the only thing a run knows about them.
    pub def ask(question: String): Result[String, String] \ { IO, Https } =
        walk(attempts(), question, "no runner was reached")

    /// One circuit's relation, asked through the run's handlers, as its text: the survey
    /// keeps those bytes as the runner spelled them.
    pub def askRelation(relation: Int64): Result[String, String] \ { IO, Clock } =
        paced(() -> ask(Overpass.Query.survey(relation)))

    /// One query, asked and read: the walk, the pace and the fence a body passes before
    /// it is an answer are above; the shape an answer comes in is `Overpass.Answer`'s.
    pub def read(question: String): Result[String, Answer] \ { IO, Https } =
        ask(question) |> Result.flatMap(Overpass.Answer.read)

    def attempts(): List[(String, Int32)] =
        runners()
            |> List.flatMap(url -> List.map(attempt -> (url, attempt), List.range(1, tries() + 1)))

    def walk(tried: List[(String, Int32)], question: String, failure: String): Result[String, String] \ { IO, Https } =
        match tried {
            case Nil => Err("every Overpass runner failed: ${failure}")
            case entry :: rest =>
                match entry {
                    case (url, at) =>
                        match send(url, question) {
                            case Ok(answer) => Ok(answer)
                            case Err(problem) =>
                                if (not List.isEmpty(rest))
                                    Net.HttpLayer.sleep(Duration.toMillis(backoff(at)))
                                else
                                    ();
                                walk(rest, question, problem)
                        }
                }
        }

    def send(url: String, question: String): Result[String, String] \ Https =
        match Https.send(post(url, question)) {
            case Err(error)   => Err(worded(error))
            case Ok(response) => answered(response, "Overpass")
        }

    /// A response, read: the body a service sent when it answered in JSON, or the sentence
    /// it answered with. Two things make a body no answer — a status that is no success,
    /// and text that is no JSON — and only the first of them is in the status: a service
    /// behind a proxy answers a request it let time out as 200 with an HTML page. `asked`
    /// is who the failure names, since the runner to re-ask and the dataset's home to
    /// re-ask are two different places to go back to.
    pub def answered(response: HttpResponse, asked: String): Result[String, String] =
        if (not Net.HttpResponse.isSuccess(response))
            Err("${asked} answered ${Net.HttpResponse.status(response)}")
        else
            kept(Net.HttpResponse.body(response), asked)

    /// One query as a form post, which is what Overpass reads rather than a query in a
    /// URL: an answer of tens of thousands of points is no URL.
    def post(url: String, question: String): HttpRequest =
        HttpRequest.postWith(url, "data=${Net.HttpLayer.urlEncode(question)}")

    /// A transport failure as the report prints it: which kind, and what the client
    /// said about it.
    pub def worded(error: IoError): String = match error {
        case IoError(kind, message) => "${kind}: ${message}"
    }

    /// A body as it is kept, if it is an answer at all: that it opens as JSON is the
    /// first thing asked of it, before its contents; what it says is read by
    /// `Overpass.Answer.read`. The refusal names whoever was asked.
    pub def kept(text: String, asked: String): Result[String, String] =
        if (String.startsWith({prefix = "{"}, text) or String.startsWith({prefix = "["}, text))
            Ok(text)
        else
            Err("${asked} answered with something that is not JSON")
}
