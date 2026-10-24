/// The asking, as far as it is testable without asking: the question a relation is
/// answered with, the text a runner's body is kept as, and the wait a failed runner is
/// left alone for. The walk itself is one call and a network, and is met by a run
/// rather than by a fixture; what is met here is everything the walk spells.
///
/// `app/tests/circuit-overpass.spec.ts` holds the runners, their order, the user agent,
/// the tries per runner and the backoff arithmetic against the other sources that
/// spell them; what is asserted here is that these spellings are what they claim.
pub mod TestOverpass {

    use Overpass.{backoff, kept, pace, pipelineQuery, runners, tries, userAgent}
    use Time.Duration

    @Test
    def testTheQuestionNamesTheRelationAndTheBodySpelling(): Unit \ Assert =
        let question = pipelineQuery(6537729i64);
        Assert.assertTrue(String.startsWith({prefix = "[out:json][timeout:120];"}, question));
        // `out body` for the ways, so a way carries its node refs, and `out skel` for
        // the nodes, which is all a chain needs of them.
        Assert.assertTrue(String.contains({substr = "way(r);out body;"}, question));
        Assert.assertTrue(String.contains({substr = "node(w);out skel;"}, question));
        Assert.assertTrue(String.contains({substr = "relation(6537729);"}, question))

    @Test
    def testBothRunnersAreWalkedInOrder(): Unit \ Assert =
        Assert.assertTrue(List.length(runners()) == 2);
        Assert.assertTrue(List.get(0, runners()) == "https://overpass-api.de/api/interpreter");
        Assert.assertTrue(List.get(1, runners()) == "https://overpass.kumi.systems/api/interpreter");
        Assert.assertTrue(tries() == 2)

    /// A run is not anonymous: a runner's operator reads a log.
    @Test
    def testARunCallsItself(): Unit \ Assert =
        Assert.assertTrue(String.startsWith({prefix = "elm-motorsport-analysis/"}, userAgent()))

    /// A runner that just failed is left alone longer each time, which is what lets a
    /// run outlast a moment of being busy.
    @Test
    def testTheBackoffGrowsWithTheAttempt(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis(backoff(1)) == 4000i64);
        Assert.assertTrue(Duration.toMillis(backoff(2)) == 8000i64);
        Assert.assertTrue(Duration.toMillis(pace()) == 1500i64)

    /// An answer is kept as the runner spelled it, once it is JSON at all — and an
    /// HTML page behind a 200 is not.
    @Test
    def testABodyIsKeptAsTheRunnerSpelledIt(): Unit \ Assert =
        let answer = "{\"elements\": []}";
        match Overpass.kept(answer) {
            case Ok(text) => Assert.assertTrue(text == answer)
            case Err(_)   => Assert.assertTrue(false)
        }

    @Test
    def testAnAnswerThatIsNotJsonIsRefused(): Unit \ Assert =
        match Overpass.kept("<html><body>504 Gateway Timeout</body></html>") {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(problem == "Overpass answered with something that is not JSON")
        }
}
