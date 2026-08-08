mod Motorsport.TestMetadata {

    use Motorsport.Metadata
    use Motorsport.Metadata.Basis
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Util.Duration
    use Util.HourClock.Hour
    use Util.Json.Encode

    /// 検査用ヘルパー: 22 列のうちテストに必要なものだけ埋めた RawLap を作る。
    def mkLap(carNumber: String, lapNumber: Int32, elapsed: String, driverName: String, class: String, group: String, team: String, manufacturer: String): RawLap =
        {
            car = {
                carNumber    = carNumber,
                class        = class,
                group        = group,
                team         = team,
                manufacturer = manufacturer
            },
            driver = {
                number = 1,
                name   = driverName
            },
            lapNumber               = lapNumber,
            lapTime                 = Duration.fromMillis(90000),
            lapImprovement          = Wec.Improvement.None,
            crossingFinishLineInPit = false,
            s1                      = { value = None, improvement = Wec.Improvement.None },
            s2                      = { value = None, improvement = Wec.Improvement.None },
            s3                      = { value = None, improvement = Wec.Improvement.None },
            kph                     = "0",
            elapsed                 = Duration.fromString(elapsed) |> Option.getWithDefault(Duration.zero()),
            hour                    = Hour.Hour(0),
            topSpeed                = "",
            pitTime                 = None,
            flagAtFl                = Wec.Flag.Green,
            miniSectors             = None
        }

    /// Gives a lap the S1 the grid is really ordered by; `mkLap` leaves it blank.
    def withS1(s1: String, lap: RawLap): RawLap =
        { s1 = { value = Duration.fromString(s1), improvement = Wec.Improvement.None } | lap }

    @Test
    def testEventDisplayNameApplied(): Unit \ Assert =
        let laps = mkLap("7", 1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota") :: Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        Assert.assertTrue(meta#name == "24 Hours of Le Mans")

    @Test
    def testUnknownEventPassThrough(): Unit \ Assert =
        let laps = mkLap("7", 1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota") :: Nil;
        let meta = Metadata.fromRawLaps("custom_event", laps);
        Assert.assertTrue(meta#name == "custom_event")

    @Test
    def testGridOrderedByLap1S1NotElapsed(): Unit \ Assert =
        // 12 は S1 で先行するが、1周目を終えたのは 7 のほうが早い。S1 を鍵に
        // 取るので 12 が position 1、7 が position 2。CSV 出現順 (7, 12) は
        // 結果に残らない。
        let laps =
            withS1("30.500", mkLap("7",  1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) ::
            withS1("29.100", mkLap("12", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche")) ::
            Nil;
        let grid = Metadata.fromRawLaps("le_mans_24h", laps)#startingGrid;
        Assert.assertTrue(grid#basis == Basis.Lap1S1);
        match grid#entries {
            case e12 :: e7 :: Nil =>
                Assert.assertTrue(e12#car#carNumber == "12");
                Assert.assertTrue(e12#position == 1);
                Assert.assertTrue(e7#car#carNumber == "7");
                Assert.assertTrue(e7#position == 2)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testGridFallsBackToLap1Elapsed(): Unit \ Assert =
        // S1 の無いフィードでは1周目 elapsed が鍵になり、basis がそう名乗る。
        let laps =
            mkLap("12", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche") ::
            mkLap("7",  1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota") ::
            Nil;
        let grid = Metadata.fromRawLaps("le_mans_24h", laps)#startingGrid;
        Assert.assertTrue(grid#basis == Basis.Lap1Elapsed);
        match grid#entries {
            case e7 :: e12 :: Nil =>
                Assert.assertTrue(e7#car#carNumber == "7");
                Assert.assertTrue(e7#position == 1);
                Assert.assertTrue(e12#car#carNumber == "12");
                Assert.assertTrue(e12#position == 2)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testMixedFeedOrdersEveryoneByElapsed(): Unit \ Assert =
        // 1台でも S1 を欠くと、読める車は全員 elapsed で並ぶ。#7 の S1 (1:10) は
        // #12 の elapsed (1:35) より小さいが、次元が違うので比較には使わない。
        // elapsed で見れば 12 が先。basis もそう名乗る。
        let laps =
            withS1("1:10.000", mkLap("7",  1, "1:40.000", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) ::
            mkLap("12", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche") ::
            Nil;
        let grid = Metadata.fromRawLaps("le_mans_24h", laps)#startingGrid;
        Assert.assertTrue(grid#basis == Basis.Lap1Elapsed);
        match grid#entries {
            case e12 :: e7 :: Nil =>
                Assert.assertTrue(e12#car#carNumber == "12");
                Assert.assertTrue(e12#position == 1);
                Assert.assertTrue(e7#car#carNumber == "7");
                Assert.assertTrue(e7#position == 2)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testUnreadableCarDoesNotCostTheFieldItsS1(): Unit \ Assert =
        // 1周目を持たない車は S1 でも elapsed でも読めないので、基準の選択には
        // 加わらない。読める2台が S1 を持つ限り basis は Lap1S1 のまま。
        let laps =
            withS1("30.500", mkLap("7",  1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) ::
            withS1("29.100", mkLap("12", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche")) ::
            mkLap("99", 2, "3:30.000", "X", "HYPERCAR", "H", "T", "M") ::
            Nil;
        let grid = Metadata.fromRawLaps("le_mans_24h", laps)#startingGrid;
        Assert.assertTrue(grid#basis == Basis.Lap1S1);
        let order = grid#entries |> List.map(e -> e#car#carNumber);
        Assert.assertTrue(order == "12" :: "7" :: "99" :: Nil)

    @Test
    def testEqualS1BreaksOnElapsedThenCarNumber(): Unit \ Assert =
        // 3台とも S1 が同値。7 は elapsed で先頭に出る。9 と 10 は elapsed も
        // 並ぶので最後の手段のカーナンバーで決まり、文字列比較なので "10" が
        // "9" より前に来る。ここは順位の判断ではなく決定性のためだけの位置な
        // ので、数値順でないことは意味を持たない。
        let laps =
            withS1("29.100", mkLap("9",  1, "1:35.365", "X", "LMGT3", "G", "T", "M")) ::
            withS1("29.100", mkLap("10", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche")) ::
            withS1("29.100", mkLap("7",  1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) ::
            Nil;
        let grid = Metadata.fromRawLaps("le_mans_24h", laps)#startingGrid;
        let order = grid#entries |> List.map(e -> e#car#carNumber);
        Assert.assertTrue(order == "7" :: "10" :: "9" :: Nil)

    @Test
    def testDriversAccumulatedInCsvOrder(): Unit \ Assert =
        let laps =
            mkLap("12", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche") ::
            mkLap("12", 2, "3:07.610", "FRIJNS",  "HYPERCAR", "H", "Hertz", "Porsche") ::
            Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        match meta#startingGrid#entries {
            case entry :: Nil =>
                Assert.assertTrue(entry#car#drivers == "STEVENS" :: "FRIJNS" :: Nil)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testDriversDeduped(): Unit \ Assert =
        let laps =
            mkLap("12", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche") ::
            mkLap("12", 2, "3:07.610", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche") ::
            mkLap("12", 3, "4:50.000", "FRIJNS",  "HYPERCAR", "H", "Hertz", "Porsche") ::
            Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        match meta#startingGrid#entries {
            case entry :: Nil =>
                Assert.assertTrue(entry#car#drivers == "STEVENS" :: "FRIJNS" :: Nil)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testCarMetaFromFirstLap(): Unit \ Assert =
        let laps =
            mkLap("7", 1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota Gazoo Racing", "Toyota") ::
            Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        match meta#startingGrid#entries {
            case entry :: Nil =>
                Assert.assertTrue(entry#car#class == "HYPERCAR");
                Assert.assertTrue(entry#car#group == "H");
                Assert.assertTrue(entry#car#team == "Toyota Gazoo Racing");
                Assert.assertTrue(entry#car#manufacturer == "Toyota")
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testCarWithoutLap1GoesToTheBack(): Unit \ Assert =
        // ラップ 1 が無い車 (lap 2 のみ) は読めないが、レースはしているので
        // 落とさず最後尾に置く。カーナンバーは 7 より小さい 1 だが、順位の
        // 付いた車を追い越さない。
        let laps =
            mkLap("1", 2, "3:30.000", "X", "HYPERCAR", "H", "T", "M") ::
            withS1("29.100", mkLap("7", 1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) ::
            Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        match meta#startingGrid#entries {
            case e7 :: e1 :: Nil =>
                Assert.assertTrue(e7#car#carNumber == "7");
                Assert.assertTrue(e7#position == 1);
                Assert.assertTrue(e1#car#carNumber == "1");
                Assert.assertTrue(e1#position == 2)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testGridWithoutAnyLap1IsUnknownButStillPlaced(): Unit \ Assert =
        // 誰も読めなくても順位は 1..n を埋める。basis がそれを推定ですらないと
        // 名乗る。並びはカーナンバー順。
        let laps =
            mkLap("99", 2, "3:30.000", "X", "HYPERCAR", "H", "T", "M") ::
            mkLap("8",  2, "3:31.000", "Y", "HYPERCAR", "H", "T", "M") ::
            Nil;
        let grid = Metadata.fromRawLaps("le_mans_24h", laps)#startingGrid;
        Assert.assertTrue(grid#basis == Basis.Unknown);
        match grid#entries {
            case e8 :: e99 :: Nil =>
                Assert.assertTrue(e8#car#carNumber == "8");
                Assert.assertTrue(e8#position == 1);
                Assert.assertTrue(e99#car#carNumber == "99");
                Assert.assertTrue(e99#position == 2)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testToJsonRendersExpectedKeys(): Unit \ Assert =
        let laps = withS1("29.100", mkLap("7", 1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) :: Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        let json = Encode.render(Metadata.toJson(meta));
        // 主要キーが出現することを確認 (構造アサーション)。
        Assert.assertTrue(String.contains({substr = "\"name\""}, json));
        Assert.assertTrue(String.contains({substr = "\"24 Hours of Le Mans\""}, json));
        Assert.assertTrue(String.contains({substr = "\"startingGrid\""}, json));
        Assert.assertTrue(String.contains({substr = "\"basis\": \"lap1_s1\""}, json));
        Assert.assertTrue(String.contains({substr = "\"entries\""}, json));
        Assert.assertTrue(String.contains({substr = "\"position\": 1"}, json));
        Assert.assertTrue(String.contains({substr = "\"carNumber\""}, json));
        Assert.assertTrue(String.contains({substr = "\"drivers\""}, json));
        Assert.assertTrue(String.contains({substr = "\"name\": \"KOBAYASHI\""}, json));
        Assert.assertTrue(String.contains({substr = "\"manufacturer\": \"Toyota\""}, json))

}
