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
                Assert.assertTrue(e12#position == Some(1));
                Assert.assertTrue(e7#car#carNumber == "7");
                Assert.assertTrue(e7#position == Some(2))
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
                Assert.assertTrue(e7#position == Some(1));
                Assert.assertTrue(e12#car#carNumber == "12");
                Assert.assertTrue(e12#position == Some(2))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testEqualS1BreaksOnElapsedThenCarNumber(): Unit \ Assert =
        // 3台とも S1 が同値。7 と 12 は elapsed で決まり、99 は 12 と elapsed も
        // 並ぶのでカーナンバーで決まる (12 < 99)。
        let laps =
            withS1("29.100", mkLap("99", 1, "1:35.365", "X", "LMGT3", "G", "T", "M")) ::
            withS1("29.100", mkLap("12", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche")) ::
            withS1("29.100", mkLap("7",  1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) ::
            Nil;
        let grid = Metadata.fromRawLaps("le_mans_24h", laps)#startingGrid;
        let order = grid#entries |> List.map(e -> e#car#carNumber);
        Assert.assertTrue(order == "7" :: "12" :: "99" :: Nil)

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
    def testCarWithoutLap1HasNoPosition(): Unit \ Assert =
        // ラップ 1 が無い車 (lap 2 のみ) は推定不能。position は None で、
        // 順位の付いた車の後ろに置かれる。
        let laps =
            withS1("29.100", mkLap("7", 1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) ::
            mkLap("99", 2, "3:30.000", "X", "HYPERCAR", "H", "T", "M") ::
            Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        match meta#startingGrid#entries {
            case e7 :: e99 :: Nil =>
                Assert.assertTrue(e7#car#carNumber == "7");
                Assert.assertTrue(e7#position == Some(1));
                Assert.assertTrue(e99#car#carNumber == "99");
                Assert.assertTrue(e99#position == None)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testGridWithoutAnyLap1IsUnknown(): Unit \ Assert =
        let laps =
            mkLap("99", 2, "3:30.000", "X", "HYPERCAR", "H", "T", "M") ::
            Nil;
        let grid = Metadata.fromRawLaps("le_mans_24h", laps)#startingGrid;
        Assert.assertTrue(grid#basis == Basis.Unknown);
        match grid#entries {
            case entry :: Nil => Assert.assertTrue(entry#position == None)
            case _            => Assert.assertTrue(false)
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
