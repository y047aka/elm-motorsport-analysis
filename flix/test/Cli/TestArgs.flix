mod Cli.TestArgs {

    use Cli.Args
    use Cli.Args.Command
    use Cli.FileTask.Rounds

    @Test
    def testParseNoArgs(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse(Nil)))

    /// Neither stage named is both of them.
    @Test
    def testParseRoot(): Unit \ Assert =
        match Args.parse("../app/static/wec" :: Nil) {
            case Ok(Command.Convert(convert)) => Assert.assertTrue(convert#root == "../app/static/wec")
            case _                            => Assert.assertTrue(false)
        }

    @Test
    def testParseLoad(): Unit \ Assert =
        match Args.parse("--load" :: "../app/static/wec" :: Nil) {
            case Ok(Command.Load(load)) => Assert.assertTrue(load#root == "../app/static/wec")
            case _                      => Assert.assertTrue(false)
        }

    /// Naming both stages is naming the run they make up.
    @Test
    def testParseLoadAndExport(): Unit \ Assert =
        match Args.parse("--load" :: "--export" :: "../app/static/wec" :: Nil) {
            case Ok(Command.Convert(_)) => Assert.assertTrue(true)
            case _                      => Assert.assertTrue(false)
        }

    @Test
    def testParseUnexpectedArgument(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("../app/static/wec" :: "extra" :: Nil)))

    /// The calendar decides what is converted, so there is no single file to
    /// redirect.
    @Test
    def testOutputIsNoLongerAnOption(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("../app/static/wec" :: "--output" :: "out.json" :: Nil)))

    @Test
    def testParseExport(): Unit \ Assert =
        match Args.parse("--export" :: "../app/static/wec" :: Nil) {
            case Ok(Command.Export(export)) => Assert.assertTrue(export#root == "../app/static/wec")
            case _                          => Assert.assertTrue(false)
        }

    /// Every stage is given the same root, whether it reads the season
    /// directories or writes them.
    @Test
    def testEveryStageTakesARoot(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("--export" :: Nil)));
        Assert.assertTrue(Result.isErr(Args.parse("--load" :: Nil)))

    @Test
    def testServeIsNotAStage(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("--export" :: "--serve" :: Nil)));
        Assert.assertTrue(Result.isErr(Args.parse("--load" :: "--serve" :: Nil)))

    @Test
    def testParseServe(): Unit \ Assert =
        match Args.parse("--serve" :: Nil) {
            case Ok(Command.Serve(serve)) => Assert.assertTrue(serve#port == 8080)
            case _                        => Assert.assertTrue(false)
        }

    @Test
    def testParseServePort(): Unit \ Assert =
        match Args.parse("--serve" :: "--port" :: "9000" :: Nil) {
            case Ok(Command.Serve(serve)) => Assert.assertTrue(serve#port == 9000)
            case _                        => Assert.assertTrue(false)
        }

    /// A converting run has nothing to serve on.
    @Test
    def testPortWithoutServe(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("../app/static/wec" :: "--port" :: "9000" :: Nil)))

    /// A run nobody narrowed writes every round out.
    @Test
    def testExportedRoundsDefaultToEvery(): Unit \ Assert =
        match Args.parse("--export" :: "../app/static/wec" :: Nil) {
            case Ok(Command.Export(export)) => Assert.assertTrue(export#exported == Rounds.Every)
            case _                          => Assert.assertTrue(false)
        }

    /// The option is repeated to name a second round, as the rounds are named
    /// one at a time and not as a list.
    @Test
    def testParseExportOnly(): Unit \ Assert =
        let args = "--export" :: "--export-only" :: "2025/le_mans_24h"
            :: "--export-only" :: "2024/fuji_6h" :: "../app/static/wec" :: Nil;
        match Args.parse(args) {
            case Ok(Command.Export(export)) =>
                Assert.assertTrue(export#exported == Rounds.Only((2025, "le_mans_24h") :: (2024, "fuji_6h") :: Nil))
            case _ => Assert.assertTrue(false)
        }

    /// A converting run loads every round and writes the ones it was narrowed
    /// to, which is what leaves `/api` answering for the rest.
    @Test
    def testAConvertingRunTakesExportOnly(): Unit \ Assert =
        match Args.parse("--export-only" :: "2025/le_mans_24h" :: "../app/static/wec" :: Nil) {
            case Ok(Command.Convert(convert)) =>
                Assert.assertTrue(convert#exported == Rounds.Only((2025, "le_mans_24h") :: Nil))
            case _ => Assert.assertTrue(false)
        }

    /// A round id says nothing about which year ran it, so half a name is no
    /// name, and neither is a name the calendar does not list.
    @Test
    def testExportOnlyNeedsARoundTheCalendarLists(): Unit \ Assert =
        let rejected = name ->
            Result.isErr(Args.parse("--export-only" :: name :: "../app/static/wec" :: Nil));
        Assert.assertTrue(rejected("le_mans_24h"));
        Assert.assertTrue(rejected("2025/"));
        Assert.assertTrue(rejected("latest/le_mans_24h"));
        Assert.assertTrue(rejected("2025/monza_6h"));
        // Ran in 2025 and 2026, and not in 2024.
        Assert.assertTrue(rejected("2024/spa_6h"))

    /// Serving is not a stage of a converting run, so it has no writing to
    /// narrow.
    @Test
    def testExportOnlyIsNotForServe(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("--serve" :: "--export-only" :: "2025/le_mans_24h" :: Nil)))

    /// The flake passes `--export-only` to every converting run, so a `--load`
    /// forwarded to one arrives beside it. A load writes nothing to narrow:
    /// the pair is redundant rather than wrong.
    @Test
    def testALoadTakesExportOnlyAndWritesNothingAnyway(): Unit \ Assert =
        match Args.parse("--export-only" :: "2025/le_mans_24h" :: "--load" :: "../app/static/wec" :: Nil) {
            case Ok(Command.Load(load)) => Assert.assertTrue(load#root == "../app/static/wec")
            case _                      => Assert.assertTrue(false)
        }

    /// Serving reads what a run loaded, so there is no directory to give it.
    @Test
    def testServeTakesNoRoot(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("--serve" :: "../app/static/wec" :: Nil)))

}
