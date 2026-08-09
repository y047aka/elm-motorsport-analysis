mod Cli.Stages.TestManifest {

    use Util.Json.Encode
    use Cli.Stages.Manifest
    use Motorsport.Calendar

    def rendered(urlRoot: String): String =
        Encode.render(Manifest.toJson(urlRoot, Calendar.seasons()))

    @Test
    def testTheCalendarJsonCarriesEverySeasonWithItsRoundsNamed(): Unit \ Assert =
        let json = rendered("/static/wec");
        Assert.assertTrue(String.contains({substr = "\"seasons\""}, json));
        Assert.assertTrue(String.contains({substr = "\"season\": 2026"}, json));
        Assert.assertTrue(String.contains({substr = "\"season\": 2025"}, json));
        Assert.assertTrue(String.contains({substr = "\"season\": 2024"}, json));
        Assert.assertTrue(String.contains({substr = "\"id\": \"le_mans_24h\""}, json));
        Assert.assertTrue(String.contains({substr = "\"name\": \"24 Hours of Le Mans\""}, json));
        Assert.assertTrue(String.contains({substr = "\"date\": \"2024-06-15\""}, json))

    /// The app fetches these rather than building them, so they are the only
    /// statement of where a round's files are.
    @Test
    def testEveryRoundStatesWhereItsFilesAre(): Unit \ Assert =
        let json = rendered("/static/wec");
        Assert.assertTrue(String.contains({substr = "\"summary\": \"/static/wec/2025/spa_6h.json\""}, json));
        Assert.assertTrue(String.contains({substr = "\"laps\": \"/static/wec/2025/spa_6h_laps.json\""}, json))

    /// Nothing about where the app serves from reaches the calendar, so moving
    /// it is one edit here and not one on each side.
    @Test
    def testTheUrlRootIsTheCallersToGive(): Unit \ Assert =
        let json = rendered("/elsewhere");
        Assert.assertTrue(String.contains({substr = "\"summary\": \"/elsewhere/2026/imola_6h.json\""}, json));
        Assert.assertTrue(not String.contains({substr = "/static/wec"}, json))

    /// The manifest is a rendering of whatever it is handed, not of the one
    /// calendar the CLI happens to hold.
    @Test
    def testAnEmptyCalendarRendersAnEmptyManifest(): Unit \ Assert =
        let json = Encode.render(Manifest.toJson("/static/wec", Nil));
        Assert.assertTrue(String.contains({substr = "\"seasons\""}, json));
        Assert.assertTrue(not String.contains({substr = "\"season\":"}, json))

}
