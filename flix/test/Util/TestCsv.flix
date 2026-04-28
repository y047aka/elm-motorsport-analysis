mod Util.TestCsv {

    use Util.Csv

    @Test
    def testParseRowSplitsBySemicolon(): Unit \ Assert =
        let row = Csv.parseRow("a;b;c");
        Assert.assertTrue(List.length(row) == 3);
        Assert.assertTrue(List.nth(0, row) == Some("a"));
        Assert.assertTrue(List.nth(2, row) == Some("c"))

    @Test
    def testParseRowEmpty(): Unit \ Assert =
        let row = Csv.parseRow("");
        Assert.assertTrue(List.length(row) == 1)

    @Test
    def testParseMultipleLines(): Unit \ Assert =
        let rows = Csv.parse("a;b" :: "c;d;e" :: Nil);
        Assert.assertTrue(List.length(rows) == 2)

}
