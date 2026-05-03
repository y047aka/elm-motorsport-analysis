mod Util.Csv.TestParser {

    use Util.Csv.Parser
    use Util.Csv.Parser.Problem

    def csv(): {fieldSeparator = Char} = {fieldSeparator = ','}

    @Test
    def testEmptyInputProducesNoRows(): Unit \ Assert =
        match Parser.parse(csv(), "") {
            case Ok(rows) => Assert.assertTrue(List.isEmpty(rows))
            case Err(_)   => Assert.assertTrue(false)
        }

    @Test
    def testSingleFieldNoNewline(): Unit \ Assert =
        match Parser.parse(csv(), "a") {
            case Ok(rows) => Assert.assertTrue(rows == ("a" :: Nil) :: Nil)
            case Err(_)   => Assert.assertTrue(false)
        }

    @Test
    def testSingleFieldTrailingNewline(): Unit \ Assert =
        match Parser.parse(csv(), "a\n") {
            case Ok(rows) => Assert.assertTrue(rows == ("a" :: Nil) :: Nil)
            case Err(_)   => Assert.assertTrue(false)
        }

    @Test
    def testTwoFieldsThreeRows(): Unit \ Assert =
        match Parser.parse(csv(), "a,b\nc,d\ne,f") {
            case Ok(rows) =>
                Assert.assertTrue(List.length(rows) == 3);
                Assert.assertTrue(List.nth(0, rows) == Some("a" :: "b" :: Nil));
                Assert.assertTrue(List.nth(2, rows) == Some("e" :: "f" :: Nil))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testEmptyFieldsPreserved(): Unit \ Assert =
        match Parser.parse(csv(), "a,,c") {
            case Ok(rows) =>
                Assert.assertTrue(rows == ("a" :: "" :: "c" :: Nil) :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testTrailingSeparatorAddsEmptyField(): Unit \ Assert =
        match Parser.parse(csv(), "a,b,") {
            case Ok(rows) =>
                Assert.assertTrue(rows == ("a" :: "b" :: "" :: Nil) :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testCustomSeparatorSemicolon(): Unit \ Assert =
        let opts = {fieldSeparator = ';'};
        match Parser.parse(opts, "a;b;c\nd;e;f") {
            case Ok(rows) =>
                Assert.assertTrue(List.length(rows) == 2);
                Assert.assertTrue(List.nth(0, rows) == Some("a" :: "b" :: "c" :: Nil))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testQuotedFieldPreservesSeparator(): Unit \ Assert =
        match Parser.parse(csv(), "\"hello, world\",x") {
            case Ok(rows) =>
                Assert.assertTrue(rows == ("hello, world" :: "x" :: Nil) :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testQuotedFieldEscapedQuote(): Unit \ Assert =
        match Parser.parse(csv(), "\"a\"\"b\",c") {
            case Ok(rows) =>
                Assert.assertTrue(rows == ("a\"b" :: "c" :: Nil) :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testCrlfLineEndings(): Unit \ Assert =
        match Parser.parse(csv(), "a,b\r\nc,d\r\n") {
            case Ok(rows) =>
                Assert.assertTrue(rows ==
                    ("a" :: "b" :: Nil) ::
                    ("c" :: "d" :: Nil) ::
                    Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testUnclosedQuoteError(): Unit \ Assert =
        match Parser.parse(csv(), "\"abc") {
            case Err(Problem.SourceEndedWithoutClosingQuote(_)) => Assert.assertTrue(true)
            case _                                                   => Assert.assertTrue(false)
        }

    @Test
    def testGarbageAfterClosingQuoteError(): Unit \ Assert =
        match Parser.parse(csv(), "\"abc\"x") {
            case Err(Problem.AdditionalCharactersAfterClosingQuote(_)) => Assert.assertTrue(true)
            case _                                                          => Assert.assertTrue(false)
        }

}
