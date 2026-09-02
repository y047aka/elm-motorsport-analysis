mod Cli.Server {

    import com.sun.net.httpserver.HttpExchange
    import com.sun.net.httpserver.HttpHandler
    import com.sun.net.httpserver.HttpServer
    import java.io.IOException
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

    /// A connection per request. `java.sql.Connection` is not thread-safe, and
    /// the requests are answered on a pool.
    def answer(databaseUrl: String, exchange: HttpExchange): Unit \ IO =
        let route = Api.route(exchange.getRequestURI().getPath());
        let response = match Jdbc.connect(databaseUrl) {
            case Err(cause) => { status = 503, contentType = "text/plain", body = cause }
            case Ok(conn)   =>
                let answered = Jdbc.runWith(conn, () -> Api.respond(route));
                Jdbc.close(conn);
                answered
        };
        send(exchange, response)

    def send(exchange: HttpExchange, response: Response): Unit \ IO =
        try {
            let bytes = response#body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", response#contentType);
            exchange.sendResponseHeaders(response#status, Int32.toInt64(Array.length(bytes)));
            let out = exchange.getResponseBody();
            out.write(bytes);
            out.close()
        } catch {
            case _e: IOException => exchange.close()
        }

}
