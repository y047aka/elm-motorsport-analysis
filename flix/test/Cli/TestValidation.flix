mod Cli.TestValidation {

    use Util.Csv
    use Cli.Validation
    use Cli.Validation.Violation
    use RawLap.RawLap

    def buildLap(num: String, lap: Int32, lapTime: String, s1: String, s2: String, s3: String, elapsed: String, hour: String): RawLap =
        let row = Csv.parseRow("${num};1;${lap};${lapTime};0;;${s1};0;${s2};0;${s3};0;100;${elapsed};${hour};0:${s1};0:${s2};0:${s3};200;Driver;;HYPERCAR;H;Team;Maker;GF;0.0;0.0;0.0;");
        match RawLap.fromCsvRow(row) {
            case Some(r) => r
            case None    => unreachable!()
        }

    /// 各バリアントの先頭引数 RawLap から carNumber を取り出す共通ヘルパー。
    def violationCar(v: Violation): String = match v {
        case Violation.SectorSum(lap, _, _, _)      => lap#carNumber
        case Violation.ElapsedDrift(lap, _, _) => lap#carNumber
        case Violation.HourElapsedOffset(lap, _, _) => lap#carNumber
        case Violation.HourUnparseable(lap, _)      => lap#carNumber
    }

    def isSectorSum(v: Violation): Bool = match v {
        case Violation.SectorSum(_, _, _, _) => true
        case _                               => false
    }

    def isElapsedDrift(v: Violation): Bool = match v {
        case Violation.ElapsedDrift(_, _, _) => true
        case _                                    => false
    }

    def isHourElapsedOffset(v: Violation): Bool = match v {
        case Violation.HourElapsedOffset(_, _, _) => true
        case _                                    => false
    }

    def isHourUnparseable(v: Violation): Bool = match v {
        case Violation.HourUnparseable(_, _) => true
        case _                               => false
    }

    @Test
    def testValidLapsProduceNoViolations(): Unit \ Assert =
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "14:04:00.000");
        let violations = Validation.detect(l1 :: l2 :: Nil);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testSectorSumMismatchDetected(): Unit \ Assert =
        // s1+s2+s3 = 30.000+60.000+30.001 = 2:00.001, lapTime = 2:00.000 -> 1ms diff.
        // elapsed と hour は lapTime に整合させて、SectorSum 単独違反になるよう調整。
        let lap = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.001", "2:00.000", "14:02:00.000");
        let violations = Validation.detect(lap :: Nil);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.SectorSum(_, lapMs, sum, _)) =>
                Assert.assertTrue(lapMs == 120000);
                Assert.assertTrue(sum == 120001)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testElapsedDriftMismatchDetected(): Unit \ Assert =
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // lap2 elapsed should be 4:00.000 but is 4:00.500
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.500", "14:04:00.500");
        let violations = Validation.detect(l1 :: l2 :: Nil);
        Assert.assertTrue(List.exists(isElapsedDrift, violations))

    @Test
    def testElapsedDriftCumulativeReportsTrailingLaps(): Unit \ Assert =
        // 累積和ベース: lap 2 で 500ms drift したら、lap 3 が「lap 2 基準では正しい」
        // (= 隣接差分なら無違反になる)場合でも、lap 3 の elapsed は累積和と一致しないため
        // 続けて違反となる。Rust 実装と同じ挙動を検証する。
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.500", "14:04:00.500");
        let l3 = buildLap("7", 3, "2:00.000", "30.000", "60.000", "30.000", "6:00.500", "14:06:00.500");
        let violations = Validation.detect(l1 :: l2 :: l3 :: Nil)
            |> List.filter(isElapsedDrift);
        Assert.assertTrue(List.length(violations) == 2);
        // 1 件目: lap 2、期待値=4:00.000(累積和)、実測=4:00.500
        // 2 件目: lap 3、期待値=6:00.000(累積和)、実測=6:00.500
        match violations {
            case v1 :: v2 :: Nil =>
                match (v1, v2) {
                    case (Violation.ElapsedDrift(lap1, exp1, act1),
                          Violation.ElapsedDrift(lap2, exp2, act2)) =>
                        Assert.assertTrue(lap1#lapNumber == 2);
                        Assert.assertTrue(exp1 == 240000);
                        Assert.assertTrue(act1 == 240500);
                        Assert.assertTrue(lap2#lapNumber == 3);
                        Assert.assertTrue(exp2 == 360000);
                        Assert.assertTrue(act2 == 360500)
                    case _ => Assert.assertTrue(false)
                }
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testHourElapsedMismatchDetected(): Unit \ Assert =
        // baseline (race-wide first valid row) = 14:02:00.000 - 2:00.000 = 13:58:00.000
        // lap 2 offset = 14:04:00.500 - 4:00.000 = 13:58:00.500 (off by 500ms vs baseline)
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "14:04:00.500");
        // make elapsed cumulative consistent so we isolate the hour-elapsed rule
        let violations = Validation.detect(l1 :: l2 :: Nil)
            |> List.filter(isHourElapsedOffset);
        Assert.assertTrue(List.length(violations) == 1)

    @Test
    def testMidnightWrapAccepted(): Unit \ Assert =
        // race starts near midnight: lap1 hour=23:59:00.000, lap2 hour=00:01:00.000 (next day)
        let l1 = buildLap("7", 1, "1:00.000", "20.000", "20.000", "20.000", "1:00.000", "23:59:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "3:00.000", "0:01:00.000");
        let violations = Validation.detect(l1 :: l2 :: Nil)
            |> List.filter(isHourElapsedOffset);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testBlankSectorTreatedAsZeroAndAnnotated(): Unit \ Assert =
        // empty s2: sum = 30+0+30 = 1:00.000, lapTime = 2:00.000 -> violation with blanks = ["s2"]
        let lap = buildLap("7", 1, "2:00.000", "30.000", "", "30.000", "2:00.000", "14:02:00.000");
        let violations = Validation.detect(lap :: Nil)
            |> List.filter(isSectorSum);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.SectorSum(_, _, _, blanks)) =>
                Assert.assertTrue(List.memberOf("s2", blanks))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testBlankLapTimeSkipped(): Unit \ Assert =
        // lapTime missing means we have no expected value -> nothing to compare
        let lap = buildLap("7", 1, "", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let violations = Validation.detect(lap :: Nil)
            |> List.filter(isSectorSum);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testMultipleCarsGroupedSeparately(): Unit \ Assert =
        // car 7 ok, car 8 has elapsed mismatch on lap 2
        let c7l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let c7l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "14:04:00.000");
        let c8l1 = buildLap("8", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let c8l2 = buildLap("8", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.500", "14:04:00.500");
        let violations = Validation.detect(c7l1 :: c7l2 :: c8l1 :: c8l2 :: Nil);
        let car7Issues = violations |> List.filter(v -> violationCar(v) == "7");
        let car8Issues = violations |> List.filter(v -> violationCar(v) == "8");
        Assert.assertTrue(List.isEmpty(car7Issues));
        Assert.assertTrue(not List.isEmpty(car8Issues))

    @Test
    def testHourUnparseableReported(): Unit \ Assert =
        // lap 2 has unparseable hour ("not-a-time") — should produce HourUnparseable
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "not-a-time");
        let violations = Validation.detect(l1 :: l2 :: Nil)
            |> List.filter(isHourUnparseable);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.HourUnparseable(_, raw)) =>
                Assert.assertTrue(raw == "not-a-time")
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testRaceWideBaselineIsolatesBadFirstLap(): Unit \ Assert =
        // race-wide baseline は CSV 全体の最初の有効な行を採用するので、
        // car "8" の lap 1 の hour が 1ms ズレていても、car "7" の lap 1 が
        // baseline になり、car "8" の lap 1 だけが違反になる(lap 2 は壊れていない)。
        let c7l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // car 8 lap 1 の hour が 1ms 進んでいる
        let c8l1 = buildLap("8", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.001");
        // car 8 lap 2 は baseline と一致(elapsed=4:00.000、hour=14:04:00.000)
        let c8l2 = buildLap("8", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "14:04:00.000");
        let violations = Validation.detect(c7l1 :: c8l1 :: c8l2 :: Nil)
            |> List.filter(isHourElapsedOffset);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.HourElapsedOffset(lap, _, _)) =>
                Assert.assertTrue(lap#carNumber == "8");
                Assert.assertTrue(lap#lapNumber == 1)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testCsvOrderPreservedInReport(): Unit \ Assert =
        // car "10" が先、car "7" が後で CSV 出現する。違反は出現順で並ぶこと。
        // (Map.toList は辞書順 "10" < "7" なので、明示的にソートしないと逆になる)
        let c10l1 = buildLap("10", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // car "10" lap 2 で elapsed が 1ms ズレ
        let c10l2 = buildLap("10", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.001", "14:04:00.001");
        let c7l1  = buildLap("7",  1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // car "7" lap 2 でも elapsed が 1ms ズレ
        let c7l2  = buildLap("7",  2, "2:00.000", "30.000", "60.000", "30.000", "4:00.001", "14:04:00.001");
        let violations = Validation.detect(c10l1 :: c10l2 :: c7l1 :: c7l2 :: Nil)
            |> List.filter(isElapsedDrift);
        Assert.assertTrue(List.length(violations) == 2);
        // 1 件目は car "10"、2 件目は car "7"(CSV 出現順)
        match violations {
            case v1 :: v2 :: Nil =>
                Assert.assertTrue(violationCar(v1) == "10");
                Assert.assertTrue(violationCar(v2) == "7")
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testValidateRendersFormattedString(): Unit \ Assert =
        // 新フォーマット: "sector-sum" slug + "expected=...ms... actual=...ms..."
        // elapsed/hour は lapTime に整合させ、メッセージ整形は SectorSum で検証する。
        let lap = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.001", "2:00.000", "14:02:00.000");
        let messages = Validation.validate("test", lap :: Nil);
        Assert.assertTrue(List.length(messages) == 1);
        match List.head(messages) {
            case Some(msg) =>
                Assert.assertTrue(String.contains({substr = "sector-sum"}, msg));
                Assert.assertTrue(String.contains({substr = "[car 7 #1]"}, msg));
                Assert.assertTrue(String.contains({substr = "expected=2:00.000 (120000ms)"}, msg));
                Assert.assertTrue(String.contains({substr = "actual=2:00.001 (120001ms)"}, msg))
            case None => Assert.assertTrue(false)
        }

    @Test
    def testHourUnparseableRendersRawString(): Unit \ Assert =
        let lap = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "garbage");
        let messages = Validation.validate("test", lap :: Nil)
            |> List.filter(m -> String.contains({substr = "hour-unparseable"}, m));
        Assert.assertTrue(List.length(messages) == 1);
        match List.head(messages) {
            case Some(msg) =>
                Assert.assertTrue(String.contains({substr = "raw=\"garbage\""}, msg))
            case None => Assert.assertTrue(false)
        }

}
