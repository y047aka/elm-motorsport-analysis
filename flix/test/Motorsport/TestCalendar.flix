mod Motorsport.TestCalendar {

    use Util.Json.Encode
    use Motorsport.Calendar

    def ids(season: Int32): List[String] =
        Calendar.rounds(season)
            |> Option.getWithDefault(Nil)
            |> List.map(r -> r#id)

    @Test
    def testASeasonKeepsTheOrderItWasRunIn(): Unit \ Assert =
        Assert.assertTrue(List.head(ids(2025)) == Some("qatar_1812km"));
        Assert.assertTrue(List.last(ids(2025)) == Some("fuji_6h"));
        Assert.assertTrue(List.length(ids(2025)) == 7)

    @Test
    def testASeasonNobodyHasFiledIsNotAnEmptyOne(): Unit \ Assert =
        Assert.assertTrue(Option.isEmpty(Calendar.rounds(2019)));
        Assert.assertTrue(Option.isEmpty(Calendar.rounds(2027)))

    @Test
    def testARoundIsDatedWithinTheSeasonItBelongsTo(): Unit \ Assert =
        Assert.assertTrue(Calendar.find(2025, "spa_6h") |> Option.map(e -> e#date) == Some("2025-05-10"));
        Assert.assertTrue(Calendar.find(2026, "spa_6h") |> Option.map(e -> e#date) == Some("2026-05-09"))

    /// The season is half of a round's name. Neither half identifies it alone,
    /// which is why the entries carry both: 2024 ran no round at Imola.
    @Test
    def testARoundASeasonDidNotRunIsNotAnEntry(): Unit \ Assert =
        Assert.assertTrue(Option.isEmpty(Calendar.find(2024, "imola_6h")));
        Assert.assertTrue(Option.isEmpty(Calendar.find(2025, "unknown_event")));
        Assert.assertTrue(Option.isEmpty(Calendar.find(2019, "spa_6h")))

    @Test
    def testTheEntriesAreEveryRoundOfEverySeason(): Unit \ Assert =
        let entries = Calendar.entries();
        let counted = Calendar.seasons() |> List.map(s -> List.length(s#rounds)) |> List.sum;
        Assert.assertTrue(List.length(entries) == counted);
        Assert.assertTrue(List.head(entries) |> Option.map(e -> e#season) == Some(2026))

    /// Stands in for the type the dates do not have. A round filed under the
    /// wrong season reads as a date, and only the year gives it away.
    @Test
    def testEveryDateIsIsoAndCarriesItsOwnSeason(): Unit \ Assert =
        let seasons = 2024 :: 2025 :: 2026 :: Nil;
        Assert.assertTrue(List.forAll(season ->
            Calendar.rounds(season)
                |> Option.getWithDefault(Nil)
                |> List.forAll(r ->
                    String.length(r#date) == 10 and
                    String.startsWith({prefix = "${season}-"}, r#date)
                ),
            seasons
        ))

    /// The latest season is the first one listed and nothing else, so this is
    /// the whole of what the index page reads to put its badge.
    @Test
    def testTheSeasonsRunNewestFirst(): Unit \ Assert =
        let years = Calendar.seasons() |> List.map(s -> s#season);
        Assert.assertTrue(years == List.sort(years) |> List.reverse)

    @Test
    def testTheCalendarJsonCarriesEverySeasonWithItsRoundsNamed(): Unit \ Assert =
        let json = Encode.render(Calendar.toJson("/static/wec"));
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
        let json = Encode.render(Calendar.toJson("/static/wec"));
        Assert.assertTrue(String.contains({substr = "\"summary\": \"/static/wec/2025/spa_6h.json\""}, json));
        Assert.assertTrue(String.contains({substr = "\"laps\": \"/static/wec/2025/spa_6h_laps.json\""}, json))

    /// Nothing under the root is baked in, so moving where the app serves from
    /// is one argument and not an edit on both sides.
    @Test
    def testTheUrlRootIsTheCallersToGive(): Unit \ Assert =
        let json = Encode.render(Calendar.toJson("/elsewhere"));
        Assert.assertTrue(String.contains({substr = "\"summary\": \"/elsewhere/2026/imola_6h.json\""}, json));
        Assert.assertTrue(not String.contains({substr = "/static/wec"}, json))

}
