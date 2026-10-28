/// The arguments of `nix run .#geometry-timing-lines`: which round, which season
/// laid beside it, how far one line may stand apart, and which flags are not the
/// report's. `TimingLines.TestFeed` drives the readings these select.
pub mod TestTimingLines {
    /// The directory the flake's own `--csv` names, so a test's parse reads like
    /// the command a reader runs.
    def csv(): List[String] = "--csv" :: "../../data/wec" :: Nil

    /// The defaults a round named alone gets: no season laid beside it, and the
    /// distance the report sets for itself.
    @Test
    def testReportReadsOneRound(): Unit \ Assert =
        match TimingLines.parse(csv() ::: "2026/cota_6h" :: Nil) {
            case Ok(request) =>
                Assert.assertTrue(request#csv == "../../data/wec");
                Assert.assertTrue(request#season == 2026);
                Assert.assertTrue(request#id == "cota_6h");
                Assert.assertTrue(request#against == None);
                Assert.assertTrue(request#tolerance == TimingLines.defaultTolerance())
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testReportTakesASeasonAndADistance(): Unit \ Assert =
        match TimingLines.parse(csv() ::: "--against" :: "2025" :: "--tolerance" :: "55.5" :: "2026/cota_6h" :: Nil) {
            case Ok(request) =>
                Assert.assertTrue(request#against == Some(2025));
                Assert.assertTrue(request#tolerance == 55.5)
            case Err(_) => Assert.assertTrue(false)
        }

    /// The last of a repeated flag is the one the reader meant.
    @Test
    def testLastFlagWins(): Unit \ Assert =
        match TimingLines.parse(csv() ::: "--against" :: "2024" :: "--against" :: "2025" :: "2026/cota_6h" :: Nil) {
            case Ok(request) => Assert.assertTrue(request#against == Some(2025))
            case Err(_)      => Assert.assertTrue(false)
        }

    @Test
    def testReportNeedsTheFeedDirectory(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(TimingLines.parse("2026/cota_6h" :: Nil)))

    /// The round is named as one the calendar lists, which is where its season's
    /// directory comes from: a bare id is no round, a season that ran some other
    /// circuit is no round either, and `--against` without a round names no run.
    @Test
    def testRoundIsNamedAsOneThereIs(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "cota_6h" :: Nil)));
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "2024/cota_6h" :: Nil)));
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "2026/cota_6h" :: "extra" :: Nil)));
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "--against" :: "24" :: "2026/cota_6h" :: Nil)));
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "--tolerance" :: "0" :: "2026/cota_6h" :: Nil)));
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "--tolerance" :: "far" :: "2026/cota_6h" :: Nil)));
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "--against" :: "2025" :: Nil)))

    /// A flag of the CLI's database-computing commands is refused, not ignored —
    /// read here once for every word, the probe's included: the argument of a flag
    /// nobody heard of would otherwise be taken as a place or a round.
    @Test
    def testTheOtherCommandsFlagsAreRefused(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "--load" :: "2026/cota_6h" :: Nil)));
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "--export" :: "2026/cota_6h" :: Nil)));
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "--serve" :: "2026/cota_6h" :: Nil)));
        Assert.assertTrue(Result.isErr(TimingLines.parse(csv() ::: "--database" :: "jdbc:h2:mem:" :: "2026/cota_6h" :: Nil)))

    /// The message the reader sees names the flag that was wrong, in the words
    /// the error carries rather than a constructor's spelling.
    @Test
    def testAnErrorNamesWhatWasWrong(): Unit \ Assert =
        match TimingLines.parse("2026/cota_6h" :: Nil) {
            case Err(e) => Assert.assertTrue(String.contains({substr = "--csv is required"}, "${e}"))
            case Ok(_)  => Assert.assertTrue(false)
        }

}
