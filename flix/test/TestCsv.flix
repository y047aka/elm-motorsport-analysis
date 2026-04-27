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
        match RawLap.fromCsvRow(row) {
            case Some(r) =>
                Assert.assertTrue(r#carNumber == "12");
                Assert.assertTrue(r#driverNumber == 1);
                Assert.assertTrue(r#lapNumber == 3);
                Assert.assertTrue(r#lapTime == "2:41.963");
                Assert.assertTrue(r#lapImprovement == 0);
                Assert.assertTrue(r#crossingFinishLineInPit == "");
                Assert.assertTrue(r#s1 == "41.805");
                Assert.assertTrue(r#s1Improvement == 0);
                Assert.assertTrue(r#s2 == "1:03.483");
                Assert.assertTrue(r#s3 == "56.675");
                Assert.assertTrue(r#kph == "101.4");
                Assert.assertTrue(r#elapsed == "6:10.938");
                Assert.assertTrue(r#hour == "11:06:38.429");
                Assert.assertTrue(r#topSpeed == "88.5");
                Assert.assertTrue(r#driverName == "Will STEVENS");
                Assert.assertTrue(r#pitTime == "");
                Assert.assertTrue(r#class == "HYPERCAR");
                Assert.assertTrue(r#group == "H");
                Assert.assertTrue(r#team == "Hertz Team JOTA");
                Assert.assertTrue(r#manufacturer == "Porsche")
            case None =>
                Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowStripsTopSpeedTrailingDotZero(): Unit \ Assert =
        let row = Csv.parseRow("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;150.0;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;");
        match RawLap.fromCsvRow(row) {
            case Some(r) =>
                Assert.assertTrue(r#topSpeed == "150")
            case None =>
                Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowShort(): Unit \ Assert =
        let row = Csv.parseRow("12;1;3");
        Assert.assertTrue(Option.isEmpty(RawLap.fromCsvRow(row)))

    @Test
    def testFromCsvRowEmpty(): Unit \ Assert =
        let row = Csv.parseRow("");
        Assert.assertTrue(Option.isEmpty(RawLap.fromCsvRow(row)))

    @Test
    def testToJsonRendersWholeKphAsInt(): Unit \ Assert =
        // kph (列12) "86.0" は JsonInt として "86" に整形される。
        let row = Csv.parseRow("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;86.0;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;");
        match RawLap.fromCsvRow(row) {
            case Some(r) =>
                let json = Json.render(RawLap.toJson(r));
                Assert.assertTrue(String.contains({substr = "\"kph\": 86,"}, json));
                Assert.assertTrue(not String.contains({substr = "\"kph\": 86.0"}, json))
            case None =>
                Assert.assertTrue(false)
        }

    @Test
    def testToJsonRendersDecimalKphAsFloat(): Unit \ Assert =
        // kph (列12) "107.1" は JsonFloat として "107.1" に整形される。
        let row = Csv.parseRow("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;107.1;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;");
        match RawLap.fromCsvRow(row) {
            case Some(r) =>
                let json = Json.render(RawLap.toJson(r));
                Assert.assertTrue(String.contains({substr = "\"kph\": 107.1"}, json))
            case None =>
                Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowNormalizesPitTime(): Unit \ Assert =
        // pitTime (列20) に正規形でない "0:01:41.031" を仕込み、Duration.normalize が
        // fromCsvRow 経由で適用されて "1:41.031" になることを確認する。
        let row = Csv.parseRow("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;0:01:41.031;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;");
        match RawLap.fromCsvRow(row) {
            case Some(r) =>
                Assert.assertTrue(r#pitTime == "1:41.031")
            case None =>
                Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowsSkipsInvalid(): Unit \ Assert =
        let lines =
            "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;" ::
            "short line" ::
            "7;1;1;1:35.421;0;;23.277;0;29.848;0;42.296;0;160.5;1:35.421;11:02:02.912;0:23.277;0:29.848;0:42.296;;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.277;29.848;42.296;" ::
            Nil;
        let records = lines |> Csv.parse |> RawLap.fromCsvRows;
        Assert.assertTrue(List.length(records) == 2);
        // 無効行スキップ後も最初のレコードは新フィールド (group/manufacturer) まで埋まっている。
        match List.head(records) {
            case Some(r) =>
                Assert.assertTrue(r#carNumber == "12");
                Assert.assertTrue(r#driverNumber == 1);
                Assert.assertTrue(r#group == "H");
                Assert.assertTrue(r#manufacturer == "Porsche")
            case None =>
                Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowEmptyTopSpeed(): Unit \ Assert =
        // CSV 列18 (TOP_SPEED) が空の行 — 非ピットラップで頻出。`stripTrailingDotZero("")` が
        // 空文字列をそのまま返し、JSON 上も `"topSpeed": ""` になることを確認する。
        let row = Csv.parseRow("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;");
        match RawLap.fromCsvRow(row) {
            case Some(r) =>
                Assert.assertTrue(r#topSpeed == "")
            case None =>
                Assert.assertTrue(false)
        }

    @Test
    def testToJsonHandlesUnparseableKphAsString(): Unit \ Assert =
        // kph が Int32/Float64 のいずれにもパースできない場合のフェイルセーフ経路。
        // kphValue は JsonString に落ち、`"kph": "not-a-number"` として出力される。
        let row = Csv.parseRow("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;not-a-number;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;");
        match RawLap.fromCsvRow(row) {
            case Some(r) =>
                let json = Json.render(RawLap.toJson(r));
                Assert.assertTrue(String.contains({substr = "\"kph\": \"not-a-number\""}, json))
            case None =>
                Assert.assertTrue(false)
        }

}
