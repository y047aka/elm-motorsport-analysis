/// The asking of OpenStreetMap, written once and asked two questions: the survey's,
/// which a kept geometry is drawn from, and the probe's, which decides — before a
/// circuit has a config — which relation a circuit is.
///
/// Two runners answer one query because a busy one answers 502 or 504. Each runner
/// is asked twice, and a runner that failed is left alone longer each time, so
/// that a run outlasts a runner's moment of being busy.
///
/// What is asked is `Overpass.Query`'s and what comes back is `Overpass.Answer`'s; this
/// module is the walking of the runners. The pace between the asks and the reading of
/// what a runner answered with are `Service`'s, shared with every other service asked.
///
/// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; an answer read
/// here is a derivative of their tags.
pub mod Overpass {

    use Circuit.Circuit
    use Net.HttpRequest.HttpRequest
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

    /// How long a runner that just failed is left alone for, longer each time that
    /// same runner is asked again.
    pub def backoff(attempt: Int32): Duration = Duration.of(4000 * attempt, Time.TimeUnit.Milliseconds)

    // ------------------------------------------------------------------- the asking

    /// One query, asked. When every runner has failed the failure carries the last
    /// thing any of them said, which is the only thing a run knows about them.
    pub def ask(question: String): Result[String, String] \ { IO, Https } =
        walk(attempts(), question, "no runner was reached")

    /// One circuit's relation, asked through the run's handlers, as its text: the survey
    /// keeps those bytes as the runner spelled them.
    pub def askRelation(relation: Int64): Result[String, String] \ { IO, Clock } =
        Service.paced(() -> ask(Overpass.Query.survey(relation)))

    /// One box's raceway ground, asked on the same pace as a relation's survey.
    pub def askBox(extent: String): Result[String, String] \ { IO, Clock } =
        Service.paced(() -> ask(Overpass.Query.box(extent)))

    /// One circuit's survey, asked of whichever ground its config names — the relation
    /// it chains from, or the box whose raceway ways it reads. Asked once from here so
    /// the live survey, `--fetch`'s guard and the freeze fence ask the same question.
    pub def askSurvey(circuit: Circuit): Result[String, String] \ { IO, Clock } =
        match (circuit#relation, circuit#box) {
            case (Some(id), _)    => askRelation(id)
            case (None, Some(at)) => askBox(Circuit.extent(at))
            case (None, None)     => Err("no ground was authored for '${circuit#word}': a circuit surveys from a relation or from a box")
        }

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
        Service.send(post(url, question), "Overpass")

    /// One query as a form post, which is what Overpass reads rather than a query in a
    /// URL: an answer of tens of thousands of points is no URL.
    def post(url: String, question: String): HttpRequest =
        HttpRequest.postWith(url, "data=${Net.HttpLayer.urlEncode(question)}")
}
