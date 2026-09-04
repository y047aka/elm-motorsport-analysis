mod Server {

    import com.sun.net.httpserver.HttpExchange
    import com.sun.net.httpserver.HttpHandler
    import com.sun.net.httpserver.HttpServer
    import java.io.ByteArrayOutputStream
    import java.io.IOException
    import java.lang.Throwable
    import java.util.zip.CRC32
    import java.util.zip.GZIPOutputStream
    import java.net.InetSocketAddress
    import java.nio.charset.StandardCharsets
    import java.util.concurrent.CountDownLatch
    import java.util.concurrent.Executors

    use Server.Api
    use Server.Api.Response
    use Server.Api.Route
    use Db.Jdbc

    def threads(): Int32 = 8

    /// Returns when the process is killed: `main` returning would take the JVM
    /// with it, and a server has nothing else to wait for.
    pub def serve(port: Int32, databaseUrl: String): Result[String, Unit] \ IO =
        try {
            let server = HttpServer.create(new InetSocketAddress(port), 0);
            discard server.createContext("/api", new HttpHandler {
                def handle(_this: HttpHandler, exchange: HttpExchange): Unit \ IO =
                    answer(databaseUrl, exchange)
            });
            server.setExecutor(Executors.newFixedThreadPool(threads()));
            server.start();
            new CountDownLatch(1).await();
            Ok()
        } catch {
            case e: IOException => Err("could not listen on port ${port} (caused by: ${e.getMessage()})")
        }

    /// Anything thrown while the answer is worked out becomes a 500. Left to
    /// fall through, it leaves the exchange open and the caller waiting: the
    /// request neither fails nor returns.
    def answer(databaseUrl: String, exchange: HttpExchange): Unit \ IO =
        let response = try {
            respond(databaseUrl, exchange)
        } catch {
            case e: Throwable => failed(exchange, e)
        };
        send(exchange, response)

    def respond(databaseUrl: String, exchange: HttpExchange): Response \ IO =
        let route = Api.route(exchange.getRequestURI().getPath());
        if (Api.needsDatabase(route))
            fromDatabase(databaseUrl, route, exchange)
        else
            // Nothing is sent, so there is nothing for the recording to hold.
            match Db.runRecording(() -> Api.respond(route)) {
                case (answered, _) => answered
            }

    /// A connection per request. `java.sql.Connection` is not thread-safe, and
    /// the requests are answered on a pool.
    ///
    /// A connection a thrown request left behind holds a read on the database
    /// until the process ends, so the close is outside the catch.
    def fromDatabase(databaseUrl: String, route: Route, exchange: HttpExchange): Response \ IO =
        match Jdbc.connect(databaseUrl) {
            case Err(cause) => { status = 503, contentType = "text/plain", body = cause }
            case Ok(conn)   =>
                let answered = try {
                    Jdbc.runWith(conn, () -> Api.respond(route))
                } catch {
                    case e: Throwable => failed(exchange, e)
                };
                Jdbc.close(conn);
                answered
        }

    def failed(exchange: HttpExchange, e: Throwable): Response \ IO =
        Sys.Console.runWithIO(() ->
            Sys.Console.eprintln("500 ${exchange.getRequestURI().getPath()}: ${e.toString()}"));
        { status = 500, contentType = "text/plain", body = "the request could not be answered" }

    /// A round is the same bytes until a run loads it again, which is what
    /// makes a tag over the body it is answered with enough.
    def send(exchange: HttpExchange, response: Response): Unit \ IO =
        try {
            let bytes = response#body.getBytes(StandardCharsets.UTF_8);
            let headers = exchange.getResponseHeaders();
            headers.add("Content-Type", response#contentType);
            let tag = if (response#status == 200) Some(etag(bytes)) else None;
            match tag {
                case None => sendBody(exchange, response#status, bytes, acceptsGzip(exchange))
                case Some(value) =>
                    headers.add("ETag", value);
                    // Left off, a reload after a run may show the round before it.
                    headers.add("Cache-Control", "no-cache");
                    if (requestHeader(exchange, "If-None-Match") == Some(value))
                        notModified(exchange)
                    else
                        sendBody(exchange, response#status, bytes, acceptsGzip(exchange))
            }
        } catch {
            case _e: Throwable => exchange.close()
        }

    def notModified(exchange: HttpExchange): Unit \ IO =
        // -1 is "no body at all", which is what a 304 is.
        exchange.sendResponseHeaders(304, -1i64);
        exchange.close()

    def sendBody(exchange: HttpExchange, status: Int32, bytes: Array[Int8, Static], compress: Bool): Unit \ IO =
        let sent = if (compress) {
            exchange.getResponseHeaders().add("Content-Encoding", "gzip");
            gzip(bytes)
        } else bytes;
        exchange.sendResponseHeaders(status, Int32.toInt64(Array.length(sent)));
        let out = exchange.getResponseBody();
        out.write(sent);
        out.close()

    def gzip(bytes: Array[Int8, Static]): Array[Int8, Static] \ IO =
        let buffer = new ByteArrayOutputStream();
        let out = new GZIPOutputStream(buffer);
        out.write(bytes);
        out.close();
        buffer.toByteArray()

    /// CRC32 of the body with its length, which is enough to notice a round
    /// that has been loaded again.
    def etag(bytes: Array[Int8, Static]): String \ IO =
        let crc = new CRC32();
        crc.update(bytes);
        "\"${Array.length(bytes)}-${crc.getValue()}\""

    def acceptsGzip(exchange: HttpExchange): Bool \ IO =
        match requestHeader(exchange, "Accept-Encoding") {
            case Some(accepted) => String.contains({substr = "gzip"}, accepted)
            case None           => false
        }

    def requestHeader(exchange: HttpExchange, name: String): Option[String] \ IO =
        Object.toOption(exchange.getRequestHeaders().getFirst(name))

}
