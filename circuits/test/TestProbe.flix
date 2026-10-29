/// The arguments of `nix run .#geometry -- probe`: which places to ask about, how far
/// round each to look, and which flags are not the probe's. `TestOverpass` and
/// `TestCandidates` drive the readings these select. The generic parser dialect —
/// a foreign flag refused rather than absorbed, the last of a repeated flag winning —
/// is read once for every word in `TestSurvey`'s parsing; what is read here is the
/// probe's own: a place kept as it was named, and a radius that means kilometres.
pub mod TestProbe {

    use Probe.{defaultRadius, parse}

    /// A place as the report is asked for one: a centre, and the box it opened.
    def centre(): List[String] = "47.9661,0.2086" :: Nil

    /// A place is kept as it was named and read as a box by the reading, not by the
    /// arguments: what `north` is wrong about is said when the box is opened. More
    /// than one place is more than one report, each asked of the same runners; a box
    /// is still one place.
    @Test
    def testEveryPlaceIsKeptAsItWasNamedAndTheProbeNeedsOne(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parse(Nil)));
        match parse("north" :: centre()) {
            case Ok(request) => Assert.assertTrue(List.get(0, request#places) == "north")
            case Err(_)      => Assert.assertTrue(false)
        };
        match parse("47.9661,0.2086,47.9925,0.2405" :: Nil) {
            case Ok(request) => Assert.assertTrue(List.length(request#places) == 1)
            case Err(_)      => Assert.assertTrue(false)
        };
        match parse("47.9661,0.2086" :: "30.13,31.42" :: Nil) {
            case Ok(request) => Assert.assertTrue(List.length(request#places) == 2)
            case Err(_)      => Assert.assertTrue(false)
        }

    /// The radius defaults, is read with `=` as the usage prints it, and the last
    /// of a repeated flag is the one the reader meant.
    @Test
    def testTheRadiusIsReadAndTheLastSpellingWins(): Unit \ Assert =
        match parse(centre()) {
            case Ok(request) =>
                Assert.assertTrue(request#radius == defaultRadius());
                Assert.assertTrue(request#places == centre())
            case Err(_) => Assert.assertTrue(false)
        };
        match parse("--radius=2.5" :: centre()) {
            case Ok(request) => Assert.assertTrue(request#radius == 2.5)
            case Err(_)      => Assert.assertTrue(false)
        };
        match parse("--radius" :: "1" :: "--radius" :: "9" :: centre()) {
            case Ok(request) => Assert.assertTrue(request#radius == 9.0)
            case Err(_)      => Assert.assertTrue(false)
        }

    /// A radius of nought widens a centre into a box that does not open, and a
    /// reader who typed one meant a distance.
    @Test
    def testTheRadiusIsADistanceAndNotNought(): Unit \ Assert =
        Assert.assertTrue(complains("is not a radius", parse("--radius" :: "0" :: centre())));
        Assert.assertTrue(complains("is not a radius", parse("--radius" :: "-3" :: centre())));
        Assert.assertTrue(complains("is not a radius", parse("--radius" :: "far" :: centre())))

    def complains(problem: String, asked: Result[Cli.Args.ArgsError, Probe.Request]): Bool =
        match asked {
            case Err(e)       => String.contains({substr = problem}, "${e}")
            case Ok(_)        => false
        }
}
