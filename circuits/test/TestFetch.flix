/// The asking's readings: which file a fetch keeps to, and which answer is worth
/// keeping. The asking itself is `TestOverpass`'s and a network's; what is met
/// here is the half that opens nothing — a word no circuit answers to, a flag that
/// names no file, an answer that surveys nothing, and the defaults a run falls back
/// to when the reader named neither.
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

    /// That some JSON came back is not yet an answer the survey can read back: a kept
    /// answer is the re-survey's evidence, so a runner's HTML page and an answer that
    /// holds no relation are refused in the survey's own words, before a byte of
    /// either is kept.
    @Test
    def testAnAnswerThatSurveysNothingIsRefused(): Unit \ Assert =
        match Circuit.byWord("cota") {
            case None    => Assert.assertTrue(false)
            case Some(circuit) =>
                match Fetch.surveyable("{}", circuit) {
                    case Ok(_) => Assert.assertTrue(false)
                    case Err(problem) =>
                        Assert.assertTrue(
                            String.contains({substr = "the answer holds no relation 6537729"}, problem)
                        )
                };
                match Fetch.surveyable("<html><body>502</body></html>", circuit) {
                    case Ok(_)        => Assert.assertTrue(false)
                    case Err(problem) => Assert.assertTrue(not String.isEmpty(problem))
                }
        }
}
