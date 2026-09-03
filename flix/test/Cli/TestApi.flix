mod Cli.TestApi {

    use Cli.Api
    use Cli.Api.Response
    use Cli.Api.Route
    use Cli.Db
    use Cli.TestRound
    use Cli.Db.TestLapRow
    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Util.Json.Encode.Extra

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }

    /// Answered without reaching a database, which is what `runRecording` is
    /// for: the routes that read nothing send nothing either.
    def offline(route: Route): Response =
        match Db.runRecording(() -> Api.respond(route)) {
            case (response, _) => response
        }

    @Test
    def theHealthPathIsItsOwnRoute(): Unit \ Assert =
        Assert.assertTrue(Api.route("/api/health") == Route.Health)

    @Test
    def aRoundIsNamedAsTheExportNamesItsFiles(): Unit \ Assert =
        Assert.assertTrue(Api.route("/api/wec/2025/fuji_6h.json") == Route.Summary(2025, "fuji_6h"));
        Assert.assertTrue(Api.route("/api/wec/2025/fuji_6h_laps.jsonl") == Route.Laps(2025, "fuji_6h"))

    /// The calendar is what says a round exists, so a path naming one it does
    /// not list is no route at all.
    @Test
    def anUnlistedRoundIsNotFound(): Unit \ Assert =
        Assert.assertTrue(Api.route("/api/wec/2025/monza_6h.json") == Route.NotFound);
        Assert.assertTrue(Api.route("/api/wec/1999/fuji_6h.json") == Route.NotFound);
        Assert.assertTrue(Api.route("/api/wec/latest/fuji_6h.json") == Route.NotFound)

    @Test
    def anythingElseIsNotFound(): Unit \ Assert =
        Assert.assertTrue(Api.route("/api/wec/2025/fuji_6h") == Route.NotFound);
        Assert.assertTrue(Api.route("/api/wec") == Route.NotFound);
        Assert.assertTrue(Api.route("/static/wec/index.json") == Route.NotFound)

    /// A database that is down is not a reason to be unable to list the
    /// rounds: the calendar is written down, not counted out of the rows.
    @Test
    def onlyARoundNeedsADatabase(): Unit \ Assert =
        Assert.assertTrue(not Api.needsDatabase(Route.Health));
        Assert.assertTrue(not Api.needsDatabase(Route.Calendar));
        Assert.assertTrue(not Api.needsDatabase(Route.NotFound));
        Assert.assertTrue(Api.needsDatabase(Route.Summary(2025, "fuji_6h")));
        Assert.assertTrue(Api.needsDatabase(Route.Laps(2025, "fuji_6h")))

    @Test
    def notFoundIsAnsweredWithA404(): Unit \ Assert =
        Assert.assertTrue(offline(Route.NotFound)#status == 404)

    /// The calendar the server hands out points back at the server.
    @Test
    def theCalendarNamesTheApisOwnPaths(): Unit \ Assert =
        let body = offline(Route.Calendar)#body;
        Assert.assertTrue(String.contains({substr = "\"summary\": \"/api/wec/2025/fuji_6h.json\""}, body));
        Assert.assertTrue(String.contains({substr = "\"laps\": \"/api/wec/2025/fuji_6h_laps.jsonl\""}, body));
        Assert.assertTrue(not String.contains({substr = "/static/"}, body))

    /// The laps come back as the export writes them: one lap per line, in the
    /// order the file listed them, rendered by the same encoder.
    @Test
    def theLapsAreTheExportsLaps(): Unit \ {IO, Assert} =
        let laps = TestLapRow.sampleLap() :: Nil;
        let response = TestRound.onRound(fuji(), laps, () -> Ok(Api.respond(Route.Laps(2025, "fuji_6h"))));
        Assert.assertTrue(response#status == 200);
        Assert.assertTrue(response#body == Extra.renderOnOneLine(Wec.toJson(TestLapRow.sampleLap())) + "\n")

    @Test
    def aRoundWithNoRowsIsAnsweredWithNoLaps(): Unit \ {IO, Assert} =
        let response = TestRound.onRound(fuji(), Nil, () -> Ok(Api.respond(Route.Laps(2025, "imola_6h"))));
        Assert.assertTrue(response#status == 200);
        Assert.assertTrue(response#body == "")

}
