/// The asking this pipeline does: the question a relation is answered with, one query
/// walked over the runners, and an answer's text handed on whole.
///
/// Two runners answer one query because a busy one answers 502 or 504 — and a runner
/// behind a proxy answers 200 with an HTML error page, which is why an answer's text is
/// looked at and not only its status. Each runner is asked twice, and a runner that
/// failed is left alone longer each time, so that a run outlasts a runner's moment of
/// being busy rather than its whole afternoon.
///
/// The answer is handed on as text rather than as elements: `Survey.answer` reads this
/// pipeline's answers — `out body`, with a way's node refs and a node's degrees in one
/// file — and what is kept beside a circuit is the runner's own bytes, so a kept answer
/// stays evidence that can be re-read by another reader years later.
///
/// The probe asks the same service a different question, in a project of its own;
/// which runners there are, in which order, and what a run calls itself are facts
/// held in both projects with no compiler between them.
/// `app/tests/circuit-overpass.spec.ts` is where that is held together.
///
/// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; an answer read
/// here is a derivative of their tags.
pub mod Overpass {

    use IoError.IoError
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https
    use Time.Clock
    use Time.Duration

    /// Each runner, in the order a run walks them. The first is the one
    /// OpenStreetMap points a caller at, and answers slowly when everyone else does
    /// too; the second answers the same query off another machine.
    pub def runners(): List[String] =
        "https://overpass-api.de/api/interpreter" ::
        "https://overpass.kumi.systems/api/interpreter" :: Nil

    /// How many times each runner is asked before the walk gives up on it.
    pub def tries(): Int32 = 2

    /// What a run calls itself. A runner's operator reads a log, and an anonymous
    /// request is a request nobody can tell from a flood.
    pub def userAgent(): String = "elm-motorsport-analysis/1.0 (circuit geometry)"

    /// The shortest interval between two requests of one run. The pace is put on once
    /// for a whole run rather than made where a walk happens to stop, so it is one
    /// number no call site can outnumber.
    pub def pace(): Duration = Duration.of(1500, Time.TimeUnit.Milliseconds)

    /// How long a runner that just failed is left alone for, longer each time that
    /// same runner is asked again.
    pub def backoff(attempt: Int32): Duration = Duration.of(4000 * attempt, Time.TimeUnit.Milliseconds)

    // ------------------------------------------------------------------ the question

    /// The question one circuit's survey is answered with: the relation, then the ways
    /// that hold its line with their tags, then the nodes those ways name. `out body`
    /// is the one spelling that carries a way's node refs and a node's degrees at once,
    /// which is what `Survey` chains a lap out of.
    pub def pipelineQuery(relation: Int64): String =
        "[out:json][timeout:120];relation(${relation});out body;way(r);out body;node(w);out skel;"

    // ------------------------------------------------------------------- the asking

    /// The handlers one run asks through: the User-Agent every request carries, the
    /// pace between them, and the client underneath. A run walks inside this, so that
    /// the pace is kept between its requests rather than each request opening a client
    /// of its own.
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

    /// Each runner twice, in the order the runners are held. The attempt travels with
    /// its runner because that is what says how long the next wait is.
    def attempts(): List[(String, Int32)] =
        List.flatMap(url -> List.map(attempt -> (url, attempt), List.range(1, tries() + 1)), runners())

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
            case Err(error) => Err(worded(error))
            case Ok(response) =>
                if (Net.HttpResponse.isSuccess(response))
                    kept(Net.HttpResponse.body(response))
                else
                    Err("Overpass answered ${Net.HttpResponse.status(response)}")
        }

    /// A query as a form post, which is what Overpass reads rather than a query in a
    /// URL: an answer of tens of thousands of points is no URL.
    def post(url: String, question: String): HttpRequest =
        HttpRequest.postWith(url, "data=${Net.HttpLayer.urlEncode(question)}")

    /// A transport failure as the report prints it: which kind, and what the client
    /// said about it.
    def worded(error: IoError): String = match error {
        case IoError(kind, message) => "${kind}: ${message}"
    }

    /// A body as it is kept, if it is an answer at all. That it is JSON is the first
    /// thing asked of it, since a proxy answers a query that timed out with an HTML
    /// page whose status is 200; what it says is read by `Survey.answer`, which is
    /// where a JSON text that stopped half way through is met.
    pub def kept(text: String): Result[String, String] =
        if (String.startsWith({prefix = "{"}, text) or String.startsWith({prefix = "["}, text))
            Ok(text)
        else
            Err("Overpass answered with something that is not JSON")
}
