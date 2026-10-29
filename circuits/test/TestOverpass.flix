/// The asking, as far as it is testable without asking: which runners, in which order,
/// under what name, how long one that just failed is left alone for, and the text a
/// runner's body is kept as. The walk itself is one call and a network, and is met by a
/// run rather than by a fixture; what is met here is everything the walk spells.
///
/// The questions it asks are `Overpass.TestQuery`'s and the answer it hands back is
/// `Overpass.TestAnswer`'s.
pub mod TestOverpass {

    use Overpass.{backoff, pace, runners, tries, userAgent}
    use Time.Duration

    /// Which runners, in which order, over https — the `Https` effect refuses a URL
    /// that is not https, so a runner spelled `http://` fails the walk rather than
    /// sending a survey over the open.
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
    /// HTML page behind a 200 is not. The refusal names the service that said it,
    /// because the survey's runner and the atlas's repository are two places to go
    /// back to and the sentence is the only thing saying which one did not answer.
    @Test
    def testABodyIsKeptAsTheRunnerSpelledIt(): Unit \ Assert =
        let answer = "{\"elements\": []}";
        match Overpass.kept(answer, "Overpass") {
            case Ok(text) => Assert.assertTrue(text == answer)
            case Err(_)   => Assert.assertTrue(false)
        };
        match Overpass.kept("<html><body>504 Gateway Timeout</body></html>", "Overpass") {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(problem == "Overpass answered with something that is not JSON")
        };
        let home = "https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/circuit-of-the-americas/raw/layers/gp.geojson";
        match Overpass.kept("<html>404: Not Found</html>", home) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(problem == "${home} answered with something that is not JSON")
        }
}
