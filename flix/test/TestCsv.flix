mod TestCsv {

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

    @Test
    def testFromCsvRowValid(): Unit \ Assert =
        let row = Csv.parseRow("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;");
        match Lap.fromCsvRow(row) {
            case Some(r) =>
                Assert.assertTrue(r#carNumber == "12");
                Assert.assertTrue(r#driverName == "Will STEVENS");
                Assert.assertTrue(r#lapNumber == "3");
                Assert.assertTrue(r#lapTime == "2:41.963");
                Assert.assertTrue(r#kph == "101.4");
                Assert.assertTrue(r#class == "HYPERCAR");
                Assert.assertTrue(r#team == "Hertz Team JOTA")
            case None =>
                Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowShort(): Unit \ Assert =
        let row = Csv.parseRow("12;1;3");
        Assert.assertTrue(Option.isEmpty(Lap.fromCsvRow(row)))

    @Test
    def testFromCsvRowEmpty(): Unit \ Assert =
        let row = Csv.parseRow("");
        Assert.assertTrue(Option.isEmpty(Lap.fromCsvRow(row)))

    @Test
    def testFromCsvRowsSkipsInvalid(): Unit \ Assert =
        let lines =
            "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;" ::
            "short line" ::
            "7;1;1;1:35.421;0;;23.277;0;29.848;0;42.296;0;160.5;1:35.421;11:02:02.912;0:23.277;0:29.848;0:42.296;;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.277;29.848;42.296;" ::
            Nil;
        let records = lines |> Csv.parse |> Lap.fromCsvRows;
        Assert.assertTrue(List.length(records) == 2)

}
