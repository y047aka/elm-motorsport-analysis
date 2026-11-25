/// The asking of a service over HTTPS, written once for every service this project asks:
/// OpenStreetMap's runners and the elevation services a survey's places are sampled from.
///
/// This is the name a run calls itself by, the pace between its requests, and the one
/// reading of what a service *answered with*. What each service is asked is its own
/// module's: `Overpass` walks its runners, `Elevation` its sources.
///
/// A file store is asked here too, for files rather than answers: the opening bytes of
/// many files at once, and a whole file streamed to whoever reads it. Neither is JSON, so
/// each is read by its status alone, and a store is not paced as a service is.
pub mod Service {

    use IoError.IoError

    import java.io.InputStream
    import java.lang.Throwable
    import java.net.URI
    import java.net.http.HttpClient
    import java.net.http.{HttpRequest => JHttpRequest}
    import java.net.http.{HttpResponse => JHttpResponse}
    import java.net.http.{HttpResponse$BodyHandlers => BodyHandlers}
    import java.util.concurrent.CompletableFuture
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

    // ---------------------------------------------------------------- files, not answers

    /// What one asking of a file store came to. A 4xx is the store's answer and is not
    /// asked again; a 5xx or a dropped connection is.
    enum Fetched[a] {
        case Got(a)
        case Refused(String)
        case Failed(String)
    }

    /// How many files' openings are asked at once.
    def together(): Int32 = 32

    /// The first `count` bytes of each of `urls`, in their order.
    pub def openings(urls: List[String], count: Int32, asked: String): Result[String, List[Vector[Int8]]] \ IO =
        let client = HttpClient.newHttpClient();
        batches(urls)
            |> Result.traverse(batch -> {
                let pending = List.map(url -> (url, client.sendAsync(ranged(url, count), BodyHandlers.ofByteArray())), batch);
                Result.traverse(pair -> match pair {
                    case (url, future) =>
                        retried(1, () -> openingOf(url, count, asked, future), () -> openingOf(url, count, asked, client.sendAsync(ranged(url, count), BodyHandlers.ofByteArray())))
                }, pending)
            })
            |> Result.map(List.flatten)

    def batches(urls: List[String]): List[List[String]] =
        if (List.isEmpty(urls)) Nil
        else List.take(together(), urls) :: batches(List.drop(together(), urls))

    def ranged(url: String, count: Int32): JHttpRequest \ IO =
        let last = count - 1;
        JHttpRequest.newBuilder(URI.create(url)).header("User-Agent", userAgent()).header("Range", "bytes=0-${last}").build()

    /// A store that ignores the range answers 200 with the whole file, which is refused
    /// rather than read: a tile is tens of megabytes.
    def openingOf(url: String, count: Int32, asked: String, future: CompletableFuture[JHttpResponse[Array[Int8, Static]]]): Fetched[Vector[Int8]] \ IO =
        try {
            let response = future.join();
            let status = response.statusCode();
            let body = response.body();
            if (status != 200 and status != 206)
                byStatus(status, url, asked)
            else if (Array.length(body) > count)
                Fetched.Refused("${asked} sent the whole of ${url}, not its first ${count} bytes")
            else
                Fetched.Got(Array.toVector(body))
        } catch {
            case e: Throwable => Fetched.Failed("${asked} answered nothing for ${url}: ${e.getMessage()}")
        }

    /// A whole file, handed to `read` as it arrives, so a file of millions of points is
    /// never held whole. A file cut off half way is asked for again from its start.
    pub def streamed(url: String, asked: String, read: InputStream -> Result[String, a] \ IO): Result[String, a] \ IO =
        let once = () -> streamedOnce(url, asked, read);
        retried(1, once, once)

    def streamedOnce(url: String, asked: String, read: InputStream -> Result[String, a] \ IO): Fetched[a] \ IO =
        try {
            let request = JHttpRequest.newBuilder(URI.create(url)).header("User-Agent", userAgent()).build();
            let response = HttpClient.newHttpClient().send(request, BodyHandlers.ofInputStream());
            let stream = response.body();
            let status = response.statusCode();
            let result =
                if (status != 200)
                    byStatus(status, url, asked)
                else
                    try {
                        match read(stream) {
                            case Ok(value)    => Fetched.Got(value)
                            case Err(problem) => Fetched.Refused(problem)
                        }
                    } catch {
                        case e: Throwable => Fetched.Failed("${asked} broke off ${url}: ${e.getMessage()}")
                    };
            closed(stream);
            result
        } catch {
            case e: Throwable => Fetched.Failed("${asked} answered nothing for ${url}: ${e.getMessage()}")
        }

    /// A stream whose reading is over, closed. A close that fails loses nothing the
    /// reading has not already kept or refused.
    def closed(stream: InputStream): Unit \ IO =
        try {
            stream.close()
        } catch {
            case _: Throwable => ()
        }

    def byStatus(status: Int32, url: String, asked: String): Fetched[a] =
        if (status >= 500) Fetched.Failed("${asked} answered ${status} for ${url}")
        else Fetched.Refused("${asked} answered ${status} for ${url}")

    /// `first` asked, then `again` after each failure that asking again could mend, as
    /// many times and as far apart as `Elevation` asks a source.
    def retried(attempt: Int32, first: Unit -> Fetched[a] \ IO, again: Unit -> Fetched[a] \ IO): Result[String, a] \ IO =
        match first() {
            case Fetched.Got(value)       => Ok(value)
            case Fetched.Refused(problem) => Err(problem)
            case Fetched.Failed(problem)  =>
                if (attempt >= Elevation.tries())
                    Err(problem)
                else {
                    Net.HttpLayer.sleep(Time.Duration.toMillis(Overpass.backoff(attempt)));
                    retried(attempt + 1, again, again)
                }
        }
}
