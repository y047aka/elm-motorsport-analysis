mod Cli.TestArgs {

    use Cli.Args
    use Cli.Args.Command

    @Test
    def testParseNoArgs(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse(Nil)))

    @Test
    def testParseRoot(): Unit \ Assert =
        match Args.parse("../app/static/wec" :: Nil) {
            case Ok(Command.Convert(convert)) => Assert.assertTrue(convert#root == "../app/static/wec")
            case _                            => Assert.assertTrue(false)
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

    /// A converting run has nothing to serve on, so a port given to one is a
    /// mistake rather than a setting with nowhere to apply.
    @Test
    def testPortWithoutServe(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("../app/static/wec" :: "--port" :: "9000" :: Nil)))

    /// Serving reads what a run loaded, so there is no directory to give it.
    @Test
    def testServeTakesNoRoot(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("--serve" :: "../app/static/wec" :: Nil)))

}
