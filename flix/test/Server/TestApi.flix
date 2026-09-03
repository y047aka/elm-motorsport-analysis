mod Server.TestApi {

    use Server.Api
    use Server.Api.Response
    use Server.Api.Route
    use Round.Render
    use Round.Summary
    use Round.TestRound
    use Db.TestLapRow
    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Util.Json.Encode.Extra

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }

    /// Answered without reaching a database, which is what `runRecording` is
    /// for.
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

    /// One path is the other with its root replaced, which is what the dev
    /// server's fallback and a bundle's own calendar are built on.
    @Test
    def theTwoRootsNameTheSameRounds(): Unit \ Assert =
        let served = offline(Route.Calendar)#body;
        let exported = Extra.render(Manifest.toJson(Cli.Manifest.urlRoot(), Motorsport.Calendar.seasons()));
        Assert.assertTrue(
            String.replace({src = Api.urlRoot()}, {dst = Cli.Manifest.urlRoot()}, served) == exported
        )

    /// The calendar the server hands out points back at the server.
    @Test
    def theCalendarNamesTheApisOwnPaths(): Unit \ Assert =
        let body = offline(Route.Calendar)#body;
        Assert.assertTrue(String.contains({substr = "\"summary\": \"/api/wec/2025/fuji_6h.json\""}, body));
        Assert.assertTrue(String.contains({substr = "\"laps\": \"/api/wec/2025/fuji_6h_laps.jsonl\""}, body));
        Assert.assertTrue(not String.contains({substr = "/static/"}, body))

    /// The round the server answers with is the round the run would have
    /// written, compared against `Round.Render`, which is what writes it.
    @Test
    def aRoundIsTheRoundTheExportWouldHold(): Unit \ {IO, Assert} =
        let laps = TestLapRow.sampleLaps();
        match served(laps) {
            case (summary, lapsBody, rendered) =>
                Assert.assertTrue(summary#status == 200);
                Assert.assertTrue(summary#body == rendered#metadataJson);
                Assert.assertTrue(lapsBody#status == 200);
                Assert.assertTrue(lapsBody#body == rendered#lapsJsonl)
        }

    def served(laps: List[RawLap]): (Response, Response, Render.Rendered) \ IO =
        TestRound.onRound(fuji(), laps, () ->
            forM(
                metadata <- Summary.read(fuji())
            ) yield (
                Api.respond(Route.Summary(2025, "fuji_6h")),
                Api.respond(Route.Laps(2025, "fuji_6h")),
                Render.render(metadata, laps)
            )
        )

    @Test
    def aRoundWithNoRowsIsAnsweredWithNoLaps(): Unit \ {IO, Assert} =
        let response = TestRound.onRound(fuji(), Nil, () -> Ok(Api.respond(Route.Laps(2025, "imola_6h"))));
        Assert.assertTrue(response#status == 200);
        Assert.assertTrue(response#body == "")

}
