/// The arguments of `nix run .#geometry -- probe`: which places to ask about, how far
/// round each to look, and which flags are not the probe's. `TestOverpass` and
/// `TestCandidates` drive the readings these select.
pub mod TestProbe {

    use Probe.{defaultRadius, parse, probeLimit}

    /// A place as the report is asked for one: a centre, and the box it opened.
    def centre(): List[String] = "47.9661,0.2086" :: Nil

    @Test
    def testProbeReadsOnePlaceAndItsOwnRadius(): Unit \ Assert =
        match parse(centre()) {
            case Ok(request) =>
                Assert.assertTrue(request#radius == defaultRadius());
                Assert.assertTrue(request#places == centre())
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testProbeReadsABoxAsOnePlace(): Unit \ Assert =
        match parse("47.9661,0.2086,47.9925,0.2405" :: Nil) {
            case Ok(request) => Assert.assertTrue(List.length(request#places) == 1)
            case Err(_)      => Assert.assertTrue(false)
        }

    /// More than one place is more than one report, each asked of the same runners.
    @Test
    def testProbeReadsEveryPlaceNamed(): Unit \ Assert =
        match parse("--radius" :: "12" :: "47.9661,0.2086" :: "30.13,31.42" :: Nil) {
            case Ok(request) =>
                Assert.assertTrue(request#radius == 12.0);
                Assert.assertTrue(List.length(request#places) == 2)
            case Err(_) => Assert.assertTrue(false)
        }

    /// The last of a repeated flag is the one the reader meant.
    @Test
    def testLastRadiusWins(): Unit \ Assert =
        match parse("--radius" :: "1" :: "--radius" :: "9" :: centre()) {
            case Ok(request) => Assert.assertTrue(request#radius == 9.0)
            case Err(_)      => Assert.assertTrue(false)
        }

    /// The `--flag=value` spelling is the one the usage prints for an option that
    /// takes an argument.
    @Test
    def testRadiusSpelledWithAnEqualsIsRead(): Unit \ Assert =
        match parse("--radius=2.5" :: centre()) {
            case Ok(request) => Assert.assertTrue(request#radius == 2.5)
            case Err(_)      => Assert.assertTrue(false)
        }

    @Test
    def testProbeNeedsAPlaceToAskAbout(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parse(Nil)))

    /// A radius of nought widens a centre into a box that does not open, and a
    /// reader who typed one meant a distance.
    @Test
    def testRadiusIsAKilometresAndMoreThanNought(): Unit \ Assert =
        Assert.assertTrue(complains("is not a radius", parse("--radius" :: "0" :: centre())));
        Assert.assertTrue(complains("is not a radius", parse("--radius" :: "-3" :: centre())));
        Assert.assertTrue(complains("is not a radius", parse("--radius" :: "far" :: centre())))

    def complains(problem: String, asked: Result[Cli.Args.ArgsError, Probe.Request]): Bool =
        match asked {
            case Err(e)       => String.contains({substr = problem}, "${e}")
            case Ok(_)        => false
        }

    /// A place is kept as it was named and read as a box by the reading, not by the
    /// arguments: what `north` is wrong about is said when the box is opened.
    @Test
    def testEveryPlaceIsKeptAsItWasNamed(): Unit \ Assert =
        match parse("north" :: centre()) {
            case Ok(request) => Assert.assertTrue(List.get(0, request#places) == "north")
            case Err(_)      => Assert.assertTrue(false)
        }

    /// A flag of a command that computes in a database is refused rather than read
    /// as a place: the argument of a flag nobody heard of would otherwise be probed
    /// as a coordinate.
    @Test
    def testTheOtherCommandsFlagsAreRefused(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parse("--database" :: "/somewhere/the.db" :: centre())));
        Assert.assertTrue(Result.isErr(parse("--csv" :: "../../data/wec" :: centre())));
        Assert.assertTrue(Result.isErr(parse("--every" :: "25" :: centre())))

    /// The limit is on probed candidates, not on the candidates an answer names:
    /// a box catches roads, and every one of them is still described.
    @Test
    def testTheProbeLimitCountsCandidatesAndNotAnswers(): Unit \ Assert =
        Assert.assertTrue(probeLimit() == 10)
}
