mod Server.TestApi {

    use Server.Api
    use Server.Api.Response
    use Server.Api.Route
    use Round.Index
    use Round.Render
    use Round.Summary
    use Motorsport.Metadata
    use Round.TestSupport
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
        let exported = Extra.render(Manifest.toJson(Cli.Export.urlRoot(), Motorsport.Calendar.seasons()));
        Assert.assertTrue(
            String.replace({src = Api.urlRoot()}, {dst = Cli.Export.urlRoot()}, served) == exported
        )

    /// The calendar the server hands out points back at the server.
    @Test
    def theCalendarNamesTheApisOwnPaths(): Unit \ Assert =
        let body = offline(Route.Calendar)#body;
        Assert.assertTrue(String.contains({substr = "\"summary\": \"/api/wec/2025/fuji_6h.json\""}, body));
        Assert.assertTrue(String.contains({substr = "\"laps\": \"/api/wec/2025/fuji_6h_laps.jsonl\""}, body));
        Assert.assertTrue(not String.contains({substr = "/static/"}, body))

    /// The round the server answers with is the round the export would write,
    /// compared against `Round.Render`, which is what either side renders it
    /// with.
    @Test
    def aRoundIsTheRoundTheExportWouldHold(): Unit \ {IO, Assert} =
        let laps = TestLapRow.sampleLaps();
        match served(laps) {
            case (summary, lapsBody, exported) =>
                Assert.assertTrue(summary#status == 200);
                Assert.assertTrue(summary#body == exported);
                Assert.assertTrue(String.contains({substr = "\"index\""}, summary#body));
                Assert.assertTrue(lapsBody#status == 200);
                Assert.assertTrue(lapsBody#body == Render.renderJsonl(laps))
        }

    def served(laps: List[RawLap]): (Response, Response, String) \ IO =
        TestSupport.onRound(fuji(), laps, () ->
            forM(
                metadata <- Summary.read(fuji());
                index    <- Index.read(fuji())
            ) yield (
                Api.respond(Route.Summary(2025, "fuji_6h")),
                Api.respond(Route.Laps(2025, "fuji_6h")),
                Render.renderSummary(metadata, index)
            )
        )

    /// A round the calendar lists and the rows hold none of. Answered out of
    /// them it would be a race that never ran.
    @Test
    def aRoundNoRunHasLoadedIsNotFound(): Unit \ {IO, Assert} =
        match unloaded() {
            case (summary, lapsBody) =>
                Assert.assertTrue(summary#status == 404);
                Assert.assertTrue(lapsBody#status == 404)
        }

    def unloaded(): (Response, Response) \ IO =
        TestSupport.onRound(fuji(), TestLapRow.sampleLaps(), () -> Ok((
            Api.respond(Route.Summary(2025, "imola_6h")),
            Api.respond(Route.Laps(2025, "imola_6h"))
        )))

}
