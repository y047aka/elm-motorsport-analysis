mod Cli.Server {

    import com.sun.net.httpserver.HttpExchange
    import com.sun.net.httpserver.HttpHandler
    import com.sun.net.httpserver.HttpServer
    import java.io.IOException
    import java.lang.Throwable
    import java.net.InetSocketAddress
    import java.nio.charset.StandardCharsets
    import java.util.concurrent.CountDownLatch
    import java.util.concurrent.Executors

    use Cli.Api
    use Cli.Api.Response
    use Cli.Db.Jdbc

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
            case e: Throwable =>
                Sys.Console.runWithIO(() ->
                    Sys.Console.eprintln("500 ${exchange.getRequestURI().getPath()}: ${e.toString()}"));
                { status = 500, contentType = "text/plain", body = "the request could not be answered" }
        };
        send(exchange, response)

    /// A connection per request. `java.sql.Connection` is not thread-safe, and
    /// the requests are answered on a pool.
    def respond(databaseUrl: String, exchange: HttpExchange): Response \ IO =
        let route = Api.route(exchange.getRequestURI().getPath());
        match Jdbc.connect(databaseUrl) {
            case Err(cause) => { status = 503, contentType = "text/plain", body = cause }
            case Ok(conn)   =>
                let answered = Jdbc.runWith(conn, () -> Api.respond(route));
                Jdbc.close(conn);
                answered
        }

    def send(exchange: HttpExchange, response: Response): Unit \ IO =
        try {
            let bytes = response#body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", response#contentType);
            exchange.sendResponseHeaders(response#status, Int32.toInt64(Array.length(bytes)));
            let out = exchange.getResponseBody();
            out.write(bytes);
            out.close()
        } catch {
            case _e: Throwable => exchange.close()
        }

}
