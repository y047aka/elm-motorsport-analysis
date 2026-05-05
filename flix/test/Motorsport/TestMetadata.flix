mod Motorsport.TestMetadata {

    use Motorsport.Metadata
    use Util.Json

    /// 検査用ヘルパー: 22 列のうちテストに必要なものだけ埋めた RawLap を作る。
    def mkLap(carNumber: String, lapNumber: Int32, elapsed: String, driverName: String, class: String, group: String, team: String, manufacturer: String): RawLap.RawLap =
        {
            carNumber               = carNumber,
            driverNumber            = 1,
            lapNumber               = lapNumber,
            lapTime                 = "1:30.000",
            lapImprovement          = 0,
            crossingFinishLineInPit = "",
            s1                      = { value = Err(""), large = Err(""), seconds = "", improvement = 0 },
            s2                      = { value = Err(""), large = Err(""), seconds = "", improvement = 0 },
            s3                      = { value = Err(""), large = Err(""), seconds = "", improvement = 0 },
            kph                     = "0",
            elapsed                 = elapsed,
            hour                    = Err(""),
            topSpeed                = "",
            driverName              = driverName,
            pitTime                 = "",
            class                   = class,
            group                   = group,
            team                    = team,
            manufacturer            = manufacturer,
            flagAtFl                = ""
        }

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
    def testStartingGridSortedByLap1Elapsed(): Unit \ Assert =
        // CSV 出現順: 12 → 7。lap1 elapsed: 12=1:35.365 (95365ms), 7=1:33.291 (93291ms)。
        // 結果: 7 が position 0、12 が position 1。
        let laps =
            mkLap("12", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche") ::
            mkLap("7",  1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota") ::
            Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        // startingGrid は CSV 出現順 (12, 7) のまま、各々の position を更新済み。
        match meta#startingGrid {
            case e12 :: e7 :: Nil =>
                Assert.assertTrue(e12#car#carNumber == "12");
                Assert.assertTrue(e12#position == 1);
                Assert.assertTrue(e7#car#carNumber == "7");
                Assert.assertTrue(e7#position == 0)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testDriversAccumulatedInCsvOrder(): Unit \ Assert =
        let laps =
            mkLap("12", 1, "1:35.365", "STEVENS", "HYPERCAR", "H", "Hertz", "Porsche") ::
            mkLap("12", 2, "3:07.610", "FRIJNS",  "HYPERCAR", "H", "Hertz", "Porsche") ::
            Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        match meta#startingGrid {
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
        match meta#startingGrid {
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
        match meta#startingGrid {
            case entry :: Nil =>
                Assert.assertTrue(entry#car#class == "HYPERCAR");
                Assert.assertTrue(entry#car#group == "H");
                Assert.assertTrue(entry#car#team == "Toyota Gazoo Racing");
                Assert.assertTrue(entry#car#manufacturer == "Toyota")
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testCarWithoutLap1KeepsZeroPosition(): Unit \ Assert =
        // ラップ 1 が無い車 (lap 2 のみ) は position = 0 のままになる。
        let laps =
            mkLap("99", 2, "3:30.000", "X", "HYPERCAR", "H", "T", "M") ::
            Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        match meta#startingGrid {
            case entry :: Nil =>
                Assert.assertTrue(entry#position == 0)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testToJsonRendersExpectedKeys(): Unit \ Assert =
        let laps = mkLap("7", 1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota") :: Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        let json = Json.render(Metadata.toJson(meta));
        // 主要キーが出現することを確認 (構造アサーション)。
        Assert.assertTrue(String.contains({substr = "\"name\""}, json));
        Assert.assertTrue(String.contains({substr = "\"24 Hours of Le Mans\""}, json));
        Assert.assertTrue(String.contains({substr = "\"startingGrid\""}, json));
        Assert.assertTrue(String.contains({substr = "\"position\""}, json));
        Assert.assertTrue(String.contains({substr = "\"carNumber\""}, json));
        Assert.assertTrue(String.contains({substr = "\"drivers\""}, json));
        Assert.assertTrue(String.contains({substr = "\"name\": \"KOBAYASHI\""}, json));
        Assert.assertTrue(String.contains({substr = "\"manufacturer\": \"Toyota\""}, json))

}
