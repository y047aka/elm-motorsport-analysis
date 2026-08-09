mod Cli.TestArgs {

    use Cli.Args

    @Test
    def testParseNoArgs(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse(Nil)))

    @Test
    def testParseRoot(): Unit \ Assert =
        match Args.parse("../app/static/wec" :: Nil) {
            case Ok(parsed) => Assert.assertTrue(parsed#root == "../app/static/wec")
            case Err(_)     => Assert.assertTrue(false)
        }

    @Test
    def testParseUnexpectedArgument(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("../app/static/wec" :: "extra" :: Nil)))

    /// The calendar decides what is converted, so there is no single file to
    /// redirect and `--output` is not a flag any more.
    @Test
    def testOutputIsNoLongerAnOption(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Args.parse("../app/static/wec" :: "--output" :: "out.json" :: Nil)))

}
