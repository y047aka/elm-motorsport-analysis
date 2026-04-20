mod TestCsv {

    @Test
    def testParseValidLine(): Unit \ Assert =
        let line = "12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;";
        match Csv.parseLine(line) {
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
    def testParseShortLine(): Unit \ Assert =
        let line = "12;1;3";
        Assert.assertTrue(Option.isEmpty(Csv.parseLine(line)))

    @Test
    def testParseEmptyLine(): Unit \ Assert =
        let line = "";
        Assert.assertTrue(Option.isEmpty(Csv.parseLine(line)))

    @Test
    def testParseLinesSkipsInvalid(): Unit \ Assert =
        let lines =
            "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;" ::
            "short line" ::
            "7;1;1;1:35.421;0;;23.277;0;29.848;0;42.296;0;160.5;1:35.421;11:02:02.912;0:23.277;0:29.848;0:42.296;;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.277;29.848;42.296;" ::
            Nil;
        let records = Csv.parseLines(lines);
        Assert.assertTrue(List.length(records) == 2)

}
