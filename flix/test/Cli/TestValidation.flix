mod Cli.TestValidation {

    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use Cli.Validation
    use Cli.Validation.Violation
    use RawLap.RawLap

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    def buildLap(num: String, lap: Int32, lapTime: String, s1: String, s2: String, s3: String, elapsed: String, hour: String): RawLap =
        let row = "${num};1;${lap};${lapTime};0;;${s1};0;${s2};0;${s3};0;100;${elapsed};${hour};0:${s1};0:${s2};0:${s3};200;Driver;;HYPERCAR;H;Team;Maker;GF;0.0;0.0;0.0;";
        let csv = header() + "\n" + row;
        match Decode.decodeCustom({fieldSeparator = ';'}, FieldNames.FieldNamesFromFirstRow, RawLap.decoder(), csv) {
            case Ok(r :: _) => r
            case _          => unreachable!()
        }

    /// Pulls carNumber off the leading RawLap arg shared by every variant.
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
        // elapsed and hour are aligned with lapTime so SectorSum is the only violation.
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
        // Cumulative-sum: when lap 2 drifts by 500ms, lap 3 is "consistent
        // relative to lap 2" (an adjacent-diff check would clear it) but still
        // disagrees with the running sum, so it must be reported too. This
        // mirrors the Rust implementation's behaviour.
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.500", "14:04:00.500");
        let l3 = buildLap("7", 3, "2:00.000", "30.000", "60.000", "30.000", "6:00.500", "14:06:00.500");
        let violations = Validation.detect(l1 :: l2 :: l3 :: Nil)
            |> List.filter(isElapsedDrift);
        Assert.assertTrue(List.length(violations) == 2);
        // 1st: lap 2, expected=4:00.000 (running sum), actual=4:00.500
        // 2nd: lap 3, expected=6:00.000 (running sum), actual=6:00.500
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
        // The race-wide baseline is taken from the first valid row in the
        // whole CSV, so even if car "8" lap 1's hour is 1 ms off, car "7"
        // lap 1 anchors the baseline and only car "8" lap 1 is flagged
        // (car "8" lap 2 is consistent and therefore clean).
        let c7l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // car 8 lap 1 hour is 1 ms ahead
        let c8l1 = buildLap("8", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.001");
        // car 8 lap 2 matches baseline (elapsed=4:00.000, hour=14:04:00.000)
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
        // car "10" appears before car "7" in the CSV; violations should
        // come back in that same order. (Map.toList orders by key, so
        // "10" < "7" lexically — without an explicit sort the report
        // would be reversed.)
        let c10l1 = buildLap("10", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // car "10" lap 2 elapsed is off by 1 ms
        let c10l2 = buildLap("10", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.001", "14:04:00.001");
        let c7l1  = buildLap("7",  1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // car "7" lap 2 elapsed is also off by 1 ms
        let c7l2  = buildLap("7",  2, "2:00.000", "30.000", "60.000", "30.000", "4:00.001", "14:04:00.001");
        let violations = Validation.detect(c10l1 :: c10l2 :: c7l1 :: c7l2 :: Nil)
            |> List.filter(isElapsedDrift);
        Assert.assertTrue(List.length(violations) == 2);
        // First violation should be car "10", second car "7" (CSV order).
        match violations {
            case v1 :: v2 :: Nil =>
                Assert.assertTrue(violationCar(v1) == "10");
                Assert.assertTrue(violationCar(v2) == "7")
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testValidateRendersFormattedString(): Unit \ Assert =
        // New format: "sector-sum" slug + "expected=...ms... actual=...ms...".
        // elapsed and hour are aligned with lapTime so the formatted output
        // is validated solely against the SectorSum case.
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
