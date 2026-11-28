pub mod Motorsport.TestCalendarFile {

    use Motorsport.CalendarFile
    use Motorsport.Circuit.Circuit

    def quoted(s: String): String =
        "\"${s}\""

    def round(id: String, date: String, name: String, circuit: String): String =
        "{\"id\": ${quoted(id)}, \"date\": ${quoted(date)}, \"name\": ${quoted(name)}, \"circuit\": ${quoted(circuit)}}"

    def spa(): String =
        round("spa_6h", "2025-05-10", "6 Hours of Spa", "spa")

    /// One season of one year, the smallest file the reader accepts.
    def file(rounds: String): String =
        "{\"series\": \"wec\", \"seasons\": [{\"season\": 2025, \"rounds\": [${rounds}]}]}"

    /// The file fails, and says which key it failed on.
    def failsWith(text: String, about: String): Bool =
        match CalendarFile.parse(text) {
            case Ok(_)  => false
            case Err(e) => String.contains({substr = about}, e)
        }

    @Test
    def testTheSmallestFileReads(): Unit \ Assert =
        match CalendarFile.parse(file(spa())) {
            case Err(_) => Assert.assertTrue(false)
            case Ok(calendar) =>
                Assert.assertTrue(calendar#series == "wec");
                Assert.assertTrue(List.map(s -> s#season, calendar#seasons) == 2025 :: Nil);
                match Motorsport.Calendar.find(calendar, 2025, "spa_6h") {
                    case None => Assert.assertTrue(false)
                    case Some(entry) =>
                        Assert.assertTrue(entry#date == "2025-05-10");
                        Assert.assertTrue(entry#name == "6 Hours of Spa");
                        Assert.assertTrue(entry#circuit == Some(Circuit.Spa))
                }
        }

    /// The date is opaque everywhere it travels, so this read is the one place
    /// its shape can be proved.
    @Test
    def testADateThatIsNotADateFailsTheRead(): Unit \ Assert =
        Assert.assertTrue(failsWith(file(round("spa_6h", "2025-5-10", "6 Hours of Spa", "spa")), "YYYY-MM-DD"));
        Assert.assertTrue(failsWith(file(round("spa_6h", "10 May 2025", "6 Hours of Spa", "spa")), "date"));
        Assert.assertTrue(failsWith(file(round("spa_6h", "", "6 Hours of Spa", "spa")), "date"))

    @Test
    def testACircuitNoSpellingKnowsFailsTheRead(): Unit \ Assert =
        Assert.assertTrue(failsWith(file(round("sepang_6h", "2025-05-10", "6 Hours of Sepang", "sepang")), "circuit"));
        Assert.assertTrue(failsWith(file(round("sepang_6h", "2025-05-10", "6 Hours of Sepang", "Spa")), "circuit"))

    @Test
    def testARoundWithoutANameFailsTheRead(): Unit \ Assert =
        let nameless = "{\"series\": \"wec\", \"seasons\": [{\"season\": 2025, \"rounds\": [{\"id\": \"spa_6h\", \"date\": \"2025-05-10\", \"circuit\": \"spa\"}]}]}";
        Assert.assertTrue(failsWith(nameless, "name"));
        Assert.assertTrue(failsWith(file(round("spa_6h", "2025-05-10", "", "spa")), "name"))

    @Test
    def testADuplicateRoundIdFailsTheRead(): Unit \ Assert =
        Assert.assertTrue(failsWith(file("${spa()}, ${spa()}"), "twice"))

    @Test
    def testASeriesThatIsNoChampionshipFailsTheRead(): Unit \ Assert =
        Assert.assertTrue(failsWith("{\"seasons\": []}", "series"));
        Assert.assertTrue(failsWith("{\"series\": \"\", \"seasons\": []}", "series"));
        Assert.assertTrue(failsWith("{\"series\": 2025, \"seasons\": []}", "series"));
        Assert.assertTrue(failsWith("not JSON at all", "not JSON"))

    /// Newest first is the whole of what makes a season the latest, so the order
    /// the file lists them in is kept rather than sorted.
    @Test
    def testTheSeasonsKeepTheOrderTheFileListsThemIn(): Unit \ Assert =
        let fuji = round("fuji_6h", "2026-09-27", "6 Hours of Fuji", "fuji");
        let two = "{\"series\": \"wec\", \"seasons\": ["
            + "{\"season\": 2026, \"rounds\": [${fuji}]}, "
            + "{\"season\": 2025, \"rounds\": [${spa()}]}]}";
        match CalendarFile.parse(two) {
            case Err(_) => Assert.assertTrue(false)
            case Ok(calendar) =>
                Assert.assertTrue(List.map(s -> s#season, calendar#seasons) == 2026 :: 2025 :: Nil)
        }

    /// A calendar is read before a run does anything else, and the file it reads
    /// is the one the run works off.
    @Test
    def testTheCalendarTheRunReadsIsReadable(): Unit \ {Assert, IO} =
        match CalendarFile.read(CalendarFile.defaultPath()) {
            case Err(_) => Assert.assertTrue(false)
            case Ok(calendar) =>
                let years = calendar#seasons |> List.map(s -> s#season);
                Assert.assertTrue(calendar#series == "wec");
                Assert.assertTrue(not List.isEmpty(years));
                Assert.assertTrue(years == List.sort(years) |> List.reverse)
        }

    /// The rounds a season ran are in the order it ran them, which is the order
    /// the export writes them and the index page lists them.
    @Test
    def testASeasonsRoundsKeepTheOrderTheFileListsThemIn(): Unit \ {Assert, IO} =
        match CalendarFile.read(CalendarFile.defaultPath()) {
            case Err(_) => Assert.assertTrue(false)
            case Ok(calendar) =>
                let days = Motorsport.Calendar.rounds(calendar, 2026)
                    |> Option.getWithDefault(Nil)
                    |> List.map(r -> r#date);
                Assert.assertTrue(not List.isEmpty(days));
                Assert.assertTrue(days == List.sort(days))
        }

}
