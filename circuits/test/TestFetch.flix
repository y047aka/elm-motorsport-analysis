/// The asking commands' readings: which file a fetch keeps to, and which answer a run
/// surveys from. The asking itself is `TestOverpass`'s and a network's; what is met
/// here is the half that opens nothing — a word no circuit answers to, a flag that
/// names no file, and the defaults a run falls back to when the reader named neither.
pub mod TestFetch {

    @Test
    def testAWordNoCircuitAnswersToIsRefused(): Unit \ Assert =
        match Fetch.parse("nurburgring" :: Nil) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) =>
                Assert.assertTrue(String.contains({substr = "no circuit is surveyed under 'nurburgring'"}, problem));
                Assert.assertTrue(String.contains({substr = "cota"}, problem))
        }

    /// No circuit named is no asking either: the usage is the answer, as it is at the
    /// survey.
    @Test
    def testAFetchNamingNoCircuitIsAnsweredWithItsUsage(): Unit \ Assert =
        match Fetch.parse("--out" :: "answer.json" :: Nil) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(String.contains({substr = "usage: nix run .#geometry-fetch"}, problem))
        }

    /// The kept answer beside the circuit's config is where an unnamed answer lands:
    /// the same file the survey reads back, which is the whole reason a fetch and a
    /// survey are two commands that need no flag to meet.
    @Test
    def testAnUnnamedAnswerLandsBesideTheConfig(): Unit \ Assert =
        match Fetch.parse("cota" :: Nil) {
            case Err(_)        => Assert.assertTrue(false)
            case Ok(command) =>
                Assert.assertTrue(command#circuit#word == "cota");
                Assert.assertTrue(command#out == "circuits/cota/overpass.json")
        }

    @Test
    def testANamedAnswerLandsWhereTheReaderSaid(): Unit \ Assert =
        match Fetch.parse("cota" :: "--out" :: "elsewhere.json" :: Nil) {
            case Err(_)        => Assert.assertTrue(false)
            case Ok(command) => Assert.assertTrue(command#out == "elsewhere.json")
        }

    /// A flag is no file: `--out --write` is a reader who meant something else, and
    /// keeping an answer under the name `--write` is a mistake no later run spots.
    @Test
    def testAFlagIsNoFileToWrite(): Unit \ Assert =
        match Fetch.parse("cota" :: "--out" :: "--write" :: Nil) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(problem == "--out names no file to write")
        }

    @Test
    def testAnOutNamingNothingIsRefused(): Unit \ Assert =
        match Fetch.parse("cota" :: "--out" :: Nil) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(problem == "--out names no file to write")
        }

    @Test
    def testAFlagNoFetchKnowsIsRefused(): Unit \ Assert =
        match Fetch.parse("cota" :: "--freeze" :: Nil) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(problem == "\"--freeze\" is no flag of this command")
        }

    /// The whole run takes the survey's flags unchanged — and no answer named is the
    /// one difference: the survey would read the kept file, and `write` asks.
    @Test
    def testTheWholeRunTakesTheSurveysFlags(): Unit \ Assert =
        match Write.parse("cota" :: "--write" :: Nil) {
            case Err(_)          => Assert.assertTrue(false)
            case Ok(command) =>
                Assert.assertTrue(command#circuit#word == "cota");
                Assert.assertTrue(command#write);
                Assert.assertTrue(not command#asked)
        }

    /// A run over a named answer is `asked` in the survey's own sense — the reader
    /// pointed at a file — whichever command it is run at.
    @Test
    def testANamedAnswerIsTheSurveysOwnReading(): Unit \ Assert =
        match Write.parse("cota" :: "--answer" :: "kept.json" :: "--write" :: Nil) {
            case Err(_)          => Assert.assertTrue(false)
            case Ok(command) =>
                Assert.assertTrue(command#asked);
                Assert.assertTrue(command#answer == "kept.json")
        }
}
