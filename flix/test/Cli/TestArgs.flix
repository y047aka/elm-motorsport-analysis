mod Cli.TestArgs {

    use Cli.Args
    use Cli.Args.Command

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

    /// Serving reads what a run loaded, so there is no directory to give it.
    @Test
    def testServeTakesNoRoot(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("--serve" :: "../app/static/wec" :: Nil)))

}
