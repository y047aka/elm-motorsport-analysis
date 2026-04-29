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
        case Violation.ElapsedCumulative(lap, _, _) => lap#carNumber
        case Violation.HourElapsedOffset(lap, _, _) => lap#carNumber
    }

    def isSectorSum(v: Violation): Bool = match v {
        case Violation.SectorSum(_, _, _, _) => true
        case _                               => false
    }

    def isElapsedCumulative(v: Violation): Bool = match v {
        case Violation.ElapsedCumulative(_, _, _) => true
        case _                                    => false
    }

    def isHourElapsedOffset(v: Violation): Bool = match v {
        case Violation.HourElapsedOffset(_, _, _) => true
        case _                                    => false
    }

    @Test
    def testValidLapsProduceNoViolations(): Unit \ Assert =
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "14:04:00.000");
        let violations = Validation.detect(l1 :: l2 :: Nil);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testSectorSumMismatchDetected(): Unit \ Assert =
        // s1+s2+s3 = 30.000+60.000+30.001 = 2:00.001, lapTime = 2:00.000 -> 1ms diff
        let lap = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.001", "2:00.001", "14:02:00.001");
        let violations = Validation.detect(lap :: Nil);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.SectorSum(_, lapMs, sum, _)) =>
                Assert.assertTrue(lapMs == 120000);
                Assert.assertTrue(sum == 120001)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testElapsedCumulativeMismatchDetected(): Unit \ Assert =
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // lap2 elapsed should be 4:00.000 but is 4:00.500
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.500", "14:04:00.500");
        let violations = Validation.detect(l1 :: l2 :: Nil);
        Assert.assertTrue(List.exists(isElapsedCumulative, violations))

    @Test
    def testHourElapsedMismatchDetected(): Unit \ Assert =
        // base offset on lap 1 = 14:00:00.000 - 2:00.000 = 13:58:00.000
        // lap 2 offset = 14:04:00.000 - 4:00.500 = 13:59:59.500 (off by 500ms)
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
    def testValidateRendersFormattedString(): Unit \ Assert =
        // validate (List[String]) の後方互換も最低限担保しておく
        let lap = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.001", "2:00.001", "14:02:00.001");
        let messages = Validation.validate("test", lap :: Nil);
        Assert.assertTrue(List.length(messages) == 1);
        match List.head(messages) {
            case Some(msg) =>
                Assert.assertTrue(String.contains({substr = "sector sum"}, msg));
                Assert.assertTrue(String.contains({substr = "[car 7 #1]"}, msg))
            case None => Assert.assertTrue(false)
        }

}
