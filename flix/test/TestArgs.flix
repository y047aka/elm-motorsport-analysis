mod TestArgs {

    @Test
    def testParseNoArgs(): Unit \ Assert =
        let result = Args.parse(Nil);
        Assert.assertTrue(Result.isErr(result))

    @Test
    def testParseInputOnly(): Unit \ Assert =
        let result = Args.parse("input.csv" :: Nil);
        match result {
            case Ok(parsed) =>
                Assert.assertTrue(parsed#inputPath == "input.csv");
                Assert.assertTrue(Option.isEmpty(parsed#outputFile))
            case Err(_) =>
                Assert.assertTrue(false)
        }

    @Test
    def testParseWithOutput(): Unit \ Assert =
        let result = Args.parse("input.csv" :: "--output" :: "out.json" :: Nil);
        match result {
            case Ok(parsed) =>
                Assert.assertTrue(parsed#inputPath == "input.csv");
                Assert.assertTrue(parsed#outputFile == Some("out.json"))
            case Err(_) =>
                Assert.assertTrue(false)
        }

    @Test
    def testParseOutputBeforeInput(): Unit \ Assert =
        let result = Args.parse("--output" :: "out.json" :: "input.csv" :: Nil);
        match result {
            case Ok(parsed) =>
                Assert.assertTrue(parsed#inputPath == "input.csv");
                Assert.assertTrue(parsed#outputFile == Some("out.json"))
            case Err(_) =>
                Assert.assertTrue(false)
        }

    @Test
    def testParseUnexpectedArgument(): Unit \ Assert =
        let result = Args.parse("input.csv" :: "extra" :: Nil);
        Assert.assertTrue(Result.isErr(result))

    @Test
    def testParseOutputWithoutValue(): Unit \ Assert =
        let result = Args.parse("input.csv" :: "--output" :: Nil);
        Assert.assertTrue(Result.isErr(result))

    @Test
    def testParseDuplicateOutput(): Unit \ Assert =
        let result = Args.parse("--output" :: "a.json" :: "--output" :: "b.json" :: "input.csv" :: Nil);
        Assert.assertTrue(Result.isErr(result))

}
