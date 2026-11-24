/// The asking of a service over HTTPS, written once for every service this project asks:
/// OpenStreetMap's runners and the elevation services a survey's places are sampled from.
///
/// This is the name a run calls itself by, the pace between its requests, and the one
/// reading of what a service *answered with*. What each service is asked is its own
/// module's: `Overpass` walks its runners, `Elevation` its sources.
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

    /// How many files' openings are asked of a file store at once. A file store is not paced
    /// as a service is.
    def together(): Int32 = 32

    /// The first `count` bytes of each of `urls`, in their order. A file store answers a
    /// range of a file, and none of this is JSON, so it is read here by its status alone.
    pub def openings(urls: List[String], count: Int32, asked: String): Result[String, List[Vector[Int8]]] \ IO =
        let client = HttpClient.newHttpClient();
        batches(urls)
            |> Result.traverse(batch -> {
                let pending = List.map(url -> (url, client.sendAsync(ranged(url, count), BodyHandlers.ofByteArray())), batch);
                Result.traverse(pair -> match pair {
                    case (url, future) => openingOf(url, future, asked)
                }, pending)
            })
            |> Result.map(List.flatten)

    def batches(urls: List[String]): List[List[String]] =
        if (List.isEmpty(urls)) Nil
        else List.take(together(), urls) :: batches(List.drop(together(), urls))

    def ranged(url: String, count: Int32): JHttpRequest \ IO =
        let last = count - 1;
        JHttpRequest.newBuilder(URI.create(url)).header("User-Agent", userAgent()).header("Range", "bytes=0-${last}").build()

    def openingOf(url: String, future: CompletableFuture[JHttpResponse[Array[Int8, Static]]], asked: String): Result[String, Vector[Int8]] \ IO =
        try {
            let response = future.join();
            let status = response.statusCode();
            if (status == 200 or status == 206)
                Ok(Array.toVector(response.body()))
            else
                Err("${asked} answered ${status} for ${url}")
        } catch {
            case e: Throwable => Err("${asked} answered nothing for ${url}: ${e.getMessage()}")
        }

    /// A whole file, handed to `read` as it arrives, so a file of millions of points is
    /// never held whole.
    pub def streamed(url: String, asked: String, read: InputStream -> Result[String, a] \ IO): Result[String, a] \ IO =
        try {
            let request = JHttpRequest.newBuilder(URI.create(url)).header("User-Agent", userAgent()).build();
            let response = HttpClient.newHttpClient().send(request, BodyHandlers.ofInputStream());
            let stream = response.body();
            let status = response.statusCode();
            let result = if (status == 200) read(stream) else Err("${asked} answered ${status} for ${url}");
            stream.close();
            result
        } catch {
            case e: Throwable => Err("${asked} answered nothing for ${url}: ${e.getMessage()}")
        }
}
