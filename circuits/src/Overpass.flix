/// The asking of OpenStreetMap, written once and asked two questions: the survey's,
/// which a kept geometry is drawn from, and the probe's, which decides — before a
/// circuit has a config — which relation a circuit is.
///
/// Two runners answer one query because a busy one answers 502 or 504 — and a runner
/// behind a proxy answers 200 with an HTML error page, which is why an answer's text is
/// looked at and not only its status. Each runner is asked twice, and a runner that
/// failed is left alone longer each time, so that a run outlasts a runner's moment of
/// being busy rather than its whole afternoon.
///
/// The two questions come back in different shapes. The survey's answer is
/// handed on as text: `Survey.answer` reads it — `out body`, with a way's node refs
/// and a node's degrees in one file — and what is kept beside a circuit is the
/// runner's own bytes, so a kept answer stays evidence that can be re-read by
/// another reader years later. A probe report is worth nothing kept, so the
/// probe's answer is read into elements here and now: `Probe` and `Candidates`
/// ask their questions through `askElements`.
///
/// The atlas reading asks another service — a dataset's repository, once, with no list
/// of runners to walk down — and reads its response here, so what an answer *is* is one
/// reading for both services.
///
/// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; an answer read
/// here is a derivative of their tags.
pub mod Overpass {

    use IoError.IoError
    use Net.HttpRequest.HttpRequest
    use Net.HttpResponse.HttpResponse
    use Net.Https.Https
    use Time.Clock
    use Time.Duration
    use Util.Json.Json
    use Util.Json.FromJson

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

    // ------------------------------------------------------------------ the question

    /// The question one circuit's survey is answered with: the relation, then the ways
    /// that hold its line with their tags, then the nodes those ways name. `out body`
    /// is the one spelling that carries a way's node refs and a node's degrees at once,
    /// which is what `Survey` chains a lap out of.
    pub def pipelineQuery(relation: Int64): String =
        "[out:json][timeout:120];relation(${relation});out body;way(r);out body;node(w);out skel;"

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

    /// One circuit's relation, asked through the run's handlers.
    pub def askRelation(relation: Int64): Result[String, String] \ { IO, Clock } =
        paced(() -> ask(pipelineQuery(relation)))

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

    /// A body as it is kept, if it is an answer at all. That it is JSON is the first
    /// thing asked of it, since a proxy answers a query that timed out with an HTML
    /// page whose status is 200; what it says is read by `Survey.answer`, which is
    /// where a JSON text that stopped half way through is met. The refusal names whoever
    /// was asked.
    pub def kept(text: String, asked: String): Result[String, String] =
        if (String.startsWith({prefix = "{"}, text) or String.startsWith({prefix = "["}, text))
            Ok(text)
        else
            Err("${asked} answered with something that is not JSON")

    // -------------------------------------------------------------- an answer, read

    /// A place on earth, in the degrees OpenStreetMap gives it.
    pub type alias Place = {
        lat = Float64,
        lon = Float64
    }

    /// Whatever a relation or a way is tagged, in OpenStreetMap's own spellings.
    pub type alias Tags = Map[String, String]

    /// One member of a relation. The role is the empty string for the ways a lap
    /// is chained from — the whole difference between the lap and the pit lane.
    pub type alias Member = {
        kind = String,
        role = String,
        ref  = Int64
    }

    /// One element of an answer. A relation carries its members and no line; a way
    /// carries the line `out geom` gave it and no other answer spells it with.
    pub type alias Element = {
        id      = Int64,
        kind    = String,
        tags    = Tags,
        members = List[Member],
        line    = List[Place]
    }

    /// One query, asked and read into its elements — the shape the probe's report
    /// and its measurements are made of. The walk, the pace and the fence a body
    /// passes before it is an answer are the asking's own above.
    pub def askElements(question: String): Result[String, List[Element]] \ { IO, Https } =
        Result.flatMap(answer, ask(question))

    /// An answer's text, read. An answer naming no elements is not a broken one — a box
    /// holding no circuit answers as exactly that — so it reads as nothing rather
    /// than as a failure.
    pub def answer(text: String): Result[String, List[Element]] =
        match kept(text, "Overpass") {
            case Err(problem) => Err(problem)
            case Ok(spelled) =>
                match Util.Json.parse(spelled) {
                    case Err(problem) => Err("${problem}")
                    case Ok(json)     => elementsOf(json)
                }
        }

    def elementsOf(j: Json): Result[String, List[Element]] =
        let items: Result[String, Option[List[Json]]] = decodeAtKeyOpt("elements", j);
        match items {
            case Err(problem)  => Err(problem)
            case Ok(None)      => Ok(Nil)
            case Ok(Some(js))  => Result.traverse(elementOf, js)
        }

    def elementOf(j: Json): Result[String, Element] =
        forM(
            kind     <- decodeAtKey("type", j);
            id       <- decodeAtKey("id", j);
            tags     <- tagsOf(j);
            members  <- membersOf(j);
            geometry <- lineOf(j)
        ) yield { id = id, kind = kind, tags = tags, members = members, line = geometry }

    /// A way's point: the node's id and tags travel with it in an `out geom`
    /// answer and are nothing to a length.
    def placeOf(j: Json): Result[String, Place] =
        forM(
            lat <- decodeAtKey("lat", j);
            lon <- decodeAtKey("lon", j)
        ) yield { lat = lat, lon = lon }

    def memberOf(j: Json): Result[String, Member] =
        forM(
            kind <- decodeAtKey("type", j);
            role <- decodeAtKeyOpt("role", j);
            ref  <- decodeAtKey("ref", j)
        ) yield { kind = kind, role = Option.getWithDefault("", role), ref = ref }

    /// Tags the answer need not carry: a way is tagged and a relation's point is
    /// not, and neither is a failure to read the other.
    def tagsOf(j: Json): Result[String, Tags] =
        decodeAtKeyOpt("tags", j) |> Result.map(t -> Option.getWithDefault(Map.empty(), t))

    def membersOf(j: Json): Result[String, List[Member]] =
        let items: Result[String, Option[List[Json]]] = decodeAtKeyOpt("members", j);
        each(memberOf, items)

    def lineOf(j: Json): Result[String, List[Place]] =
        let items: Result[String, Option[List[Json]]] = decodeAtKeyOpt("geometry", j);
        each(placeOf, items)

    /// A list the answer need not carry: absent, it is nothing; present, each item
    /// is read by the reading that knows what an item of it is.
    def each(read: Json -> Result[String, a], value: Result[String, Option[List[Json]]]): Result[String, List[a]] =
        match value {
            case Err(problem) => Err(problem)
            case Ok(None)     => Ok(Nil)
            case Ok(Some(js)) => Result.traverse(read, js)
        }

    def decodeAtKey(key: String, j: Json): Result[String, a] with FromJson[a] =
        FromJson.decodeAtKey(key, j) |> Result.mapErr(e -> "${e}")

    def decodeAtKeyOpt(key: String, j: Json): Result[String, Option[a]] with FromJson[a] =
        FromJson.decodeAtKeyOpt(key, j) |> Result.mapErr(e -> "${e}")
}
