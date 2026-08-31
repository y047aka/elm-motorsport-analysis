mod Cli.Stages.TestValidation {

    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use Util.Duration
    use Cli.TestRound
    use Cli.Stages.Validation
    use Cli.Stages.Validation.Violation
    use Motorsport.Calendar.Entry
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    def entry(): Entry = { season = 2025, id = "test", date = "2025-01-01" }

    def detect(laps: List[RawLap]): List[Violation] \ IO =
        TestRound.onRound(entry(), laps, () -> Validation.detect(entry()))

    def validate(laps: List[RawLap]): List[String] \ IO =
        TestRound.onRound(entry(), laps, () -> Validation.validate(entry()))

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    def leMansHeader(): String =
        header() +
        ";SCL2_time;SCL2_elapsed;Z4_time;Z4_elapsed;IP1_time;IP1_elapsed" +
        ";Z12_time;Z12_elapsed;SCLC_time;SCLC_elapsed;A7-1_time;A7-1_elapsed;IP2_time;IP2_elapsed" +
        ";A8-1_time;A8-1_elapsed;SCLB_time;SCLB_elapsed;PORIN_time;PORIN_elapsed;POROUT_time;POROUT_elapsed;PITREF_time;PITREF_elapsed;SCL1_time;SCL1_elapsed;FORDOUT_time;FORDOUT_elapsed;FL_time;FL_elapsed"

    def buildLap(num: String, lap: Int32, lapTime: String, s1: String, s2: String, s3: String, elapsed: String, hour: String): RawLap =
        let row = "${num};1;${lap};${lapTime};0;;${s1};0;${s2};0;${s3};0;100;${elapsed};${hour};0:${s1};0:${s2};0:${s3};200;Driver;;HYPERCAR;H;Team;Maker;GF;${s1};${s2};${s3};";
        let csv = header() + "\n" + row;
        match Decode.decodeCustom({fieldSeparator = ';'}, FieldNames.FieldNamesFromFirstRow, Wec.decoder(), csv) {
            case Ok(r :: _) => r
            case _          => unreachable!()
        }

    /// Build a Le Mans-shaped lap. `miniTail` is the raw 30-column suffix
    /// (`time;elapsed;...`) appended after the standard fields.
    ///
    /// Note: `s3` must be a plain-seconds string (e.g. `"64.000"`, not
    /// `"1:04.000"`) because the Le Mans CSV has trailing `S3_SECONDS`-style
    /// columns that go through `Float64.fromString`. Real Le Mans S3 values
    /// run 1:30+, so this fixture is intentionally simplified — the integrity
    /// rules under test don't care about realistic lap geometry, only the
    /// arithmetic relationships between the columns.
    def buildLeMansLap(num: String, lap: Int32, lapTime: String, s1: String, s2: String, s3: String, elapsed: String, hour: String, miniTail: String): RawLap =
        buildLeMansLapWith(num, lap, lapTime, s1, s2, s3, elapsed, hour, miniTail, "", "")

    /// Le Mans lap builder with explicit values for the
    /// CROSSING_FINISH_LINE_IN_PIT and PIT_TIME columns. Pass `box = "B"`
    /// to mark the lap as a pit-entry lap, or `pitTime = "30.500"` to
    /// record a pit-stop duration.
    def buildLeMansLapWith(num: String, lap: Int32, lapTime: String, s1: String, s2: String, s3: String, elapsed: String, hour: String, miniTail: String, box: String, pitTime: String): RawLap =
        let row = "${num};1;${lap};${lapTime};0;${box};${s1};0;${s2};0;${s3};0;100;${elapsed};${hour};0:${s1};0:${s2};0:${s3};200;Driver;${pitTime};HYPERCAR;H;Team;Maker;GF;${s1};${s2};${s3};${miniTail}";
        let csv = leMansHeader() + "\n" + row;
        match Decode.decodeCustom({fieldSeparator = ';'}, FieldNames.FieldNamesFromFirstRow, Wec.decoder(), csv) {
            case Ok(r :: _) => r
            case _          => unreachable!()
        }

    /// 15 sub-sectors with the trailing FORDOUT and FL_time blanked out —
    /// the canonical "pit-entry lap" pattern observed in real Le Mans data
    /// (the car skips the main-line FORDOUT loop and crosses FL inside the
    /// pit lane). The FL_elapsed value is preserved at lapTime so the lap
    /// itself is still completed at the finish line.
    def pitEntryMiniTail(): String =
        "8.000;8.000;8.000;16.000;8.000;24.000" +
        ";8.000;32.000;8.000;40.000;8.000;48.000;8.000;56.000" +
        ";8.000;1:04.000;8.000;1:12.000;8.000;1:20.000;8.000;1:28.000;8.000;1:36.000;8.000;1:44.000;;;;2:00.000"

    /// Track-limits violation at the second Ford chicane: SCL1 + FORDOUT
    /// loops not triggered. FL_elapsed is preserved at lapTime since the
    /// car still crosses the finish line. The on-track markers retain
    /// their straight-line cumulative times.
    def trackLimits_SCL1_FORDOUT_MiniTail(): String =
        "8.000;8.000;8.000;16.000;8.000;24.000" +
        ";8.000;32.000;8.000;40.000;8.000;48.000;8.000;56.000" +
        ";8.000;1:04.000;8.000;1:12.000;8.000;1:20.000;8.000;1:28.000;8.000;1:36.000;;;;;8.000;2:00.000"

    /// Track-limits violation at the first Ford chicane: PITREF + SCL1
    /// loops not triggered. The car re-joins the main racing line before
    /// FORDOUT, so FORDOUT and FL fire normally.
    def trackLimits_PITREF_SCL1_MiniTail(): String =
        "8.000;8.000;8.000;16.000;8.000;24.000" +
        ";8.000;32.000;8.000;40.000;8.000;48.000;8.000;56.000" +
        ";8.000;1:04.000;8.000;1:12.000;8.000;1:20.000;8.000;1:28.000;;;;;8.000;1:52.000;8.000;2:00.000"

    /// Pulls carNumber off the leading RawLap arg shared by every variant.
    def violationCar(v: Violation): String = match v {
        case Violation.SectorSum(lap, _, _, _)      => lap#carNumber
        case Violation.ElapsedDrift(lap, _, _) => lap#carNumber
        case Violation.HourElapsedOffset(lap, _, _) => lap#carNumber
        case Violation.MiniSectorSum(lap, _, _, _)  => lap#carNumber
        case Violation.MiniSectorElapsedMonotonic(lap, _, _, _, _) => lap#carNumber
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

    def isMiniSectorSum(v: Violation): Bool = match v {
        case Violation.MiniSectorSum(_, _, _, _) => true
        case _                                   => false
    }

    def isMiniSectorMonotonic(v: Violation): Bool = match v {
        case Violation.MiniSectorElapsedMonotonic(_, _, _, _, _) => true
        case _                                                    => false
    }

    @Test
    def testValidLapsProduceNoViolations(): Unit \ {Assert, IO} =
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "14:04:00.000");
        let violations = detect(l1 :: l2 :: Nil);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testSectorSumMismatchDetected(): Unit \ {Assert, IO} =
        // s1+s2+s3 = 30.000+60.000+30.001 = 2:00.001, lapTime = 2:00.000 -> 1ms diff.
        // elapsed and hour are aligned with lapTime so SectorSum is the only violation.
        let lap = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.001", "2:00.000", "14:02:00.000");
        let violations = detect(lap :: Nil);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.SectorSum(_, lapMs, sum, _)) =>
                Assert.assertTrue(lapMs == Duration.fromMillis(120000));
                Assert.assertTrue(sum == Duration.fromMillis(120001))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testElapsedDriftMismatchDetected(): Unit \ {Assert, IO} =
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // lap2 elapsed should be 4:00.000 but is 4:00.500
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.500", "14:04:00.500");
        let violations = detect(l1 :: l2 :: Nil);
        Assert.assertTrue(List.exists(isElapsedDrift, violations))

    @Test
    def testElapsedDriftCumulativeReportsTrailingLaps(): Unit \ {Assert, IO} =
        // Cumulative-sum: when lap 2 drifts by 500ms, lap 3 is "consistent
        // relative to lap 2" (an adjacent-diff check would clear it) but still
        // disagrees with the running sum, so it must be reported too. This
        // mirrors the Rust implementation's behaviour.
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.500", "14:04:00.500");
        let l3 = buildLap("7", 3, "2:00.000", "30.000", "60.000", "30.000", "6:00.500", "14:06:00.500");
        let violations = detect(l1 :: l2 :: l3 :: Nil)
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
                        Assert.assertTrue(exp1 == Duration.fromMillis(240000));
                        Assert.assertTrue(act1 == Duration.fromMillis(240500));
                        Assert.assertTrue(lap2#lapNumber == 3);
                        Assert.assertTrue(exp2 == Duration.fromMillis(360000));
                        Assert.assertTrue(act2 == Duration.fromMillis(360500))
                    case _ => Assert.assertTrue(false)
                }
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testHourElapsedMismatchDetected(): Unit \ {Assert, IO} =
        // baseline (race-wide first valid row) = 14:02:00.000 - 2:00.000 = 13:58:00.000
        // lap 2 offset = 14:04:00.500 - 4:00.000 = 13:58:00.500 (off by 500ms vs baseline)
        let l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "14:04:00.500");
        // make elapsed cumulative consistent so we isolate the hour-elapsed rule
        let violations = detect(l1 :: l2 :: Nil)
            |> List.filter(isHourElapsedOffset);
        Assert.assertTrue(List.length(violations) == 1)

    @Test
    def testMidnightWrapAccepted(): Unit \ {Assert, IO} =
        // race starts near midnight: lap1 hour=23:59:00.000, lap2 hour=00:01:00.000 (next day)
        let l1 = buildLap("7", 1, "1:00.000", "20.000", "20.000", "20.000", "1:00.000", "23:59:00.000");
        let l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "3:00.000", "0:01:00.000");
        let violations = detect(l1 :: l2 :: Nil)
            |> List.filter(isHourElapsedOffset);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testBlankSectorTreatedAsZeroAndAnnotated(): Unit \ {Assert, IO} =
        // empty s2: sum = 30+0+30 = 1:00.000, lapTime = 2:00.000 -> violation with blanks = ["s2"]
        let lap = buildLap("7", 1, "2:00.000", "30.000", "", "30.000", "2:00.000", "14:02:00.000");
        let violations = detect(lap :: Nil)
            |> List.filter(isSectorSum);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.SectorSum(_, _, _, blanks)) =>
                Assert.assertTrue(List.memberOf("s2", blanks))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testMultipleCarsGroupedSeparately(): Unit \ {Assert, IO} =
        // car 7 ok, car 8 has elapsed mismatch on lap 2
        let c7l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let c7l2 = buildLap("7", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "14:04:00.000");
        let c8l1 = buildLap("8", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let c8l2 = buildLap("8", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.500", "14:04:00.500");
        let violations = detect(c7l1 :: c7l2 :: c8l1 :: c8l2 :: Nil);
        let car7Issues = violations |> List.filter(v -> violationCar(v) == "7");
        let car8Issues = violations |> List.filter(v -> violationCar(v) == "8");
        Assert.assertTrue(List.isEmpty(car7Issues));
        Assert.assertTrue(not List.isEmpty(car8Issues))

    @Test
    def testRaceWideBaselineIsolatesBadFirstLap(): Unit \ {Assert, IO} =
        // The race-wide baseline is taken from the first valid row in the
        // whole CSV, so even if car "8" lap 1's hour is 1 ms off, car "7"
        // lap 1 anchors the baseline and only car "8" lap 1 is flagged
        // (car "8" lap 2 is consistent and therefore clean).
        let c7l1 = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        // car 8 lap 1 hour is 1 ms ahead
        let c8l1 = buildLap("8", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.001");
        // car 8 lap 2 matches baseline (elapsed=4:00.000, hour=14:04:00.000)
        let c8l2 = buildLap("8", 2, "2:00.000", "30.000", "60.000", "30.000", "4:00.000", "14:04:00.000");
        let violations = detect(c7l1 :: c8l1 :: c8l2 :: Nil)
            |> List.filter(isHourElapsedOffset);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.HourElapsedOffset(lap, _, _)) =>
                Assert.assertTrue(lap#carNumber == "8");
                Assert.assertTrue(lap#lapNumber == 1)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testCsvOrderPreservedInReport(): Unit \ {Assert, IO} =
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
        let violations = detect(c10l1 :: c10l2 :: c7l1 :: c7l2 :: Nil)
            |> List.filter(isElapsedDrift);
        Assert.assertTrue(List.length(violations) == 2);
        // First violation should be car "10", second car "7" (CSV order).
        match violations {
            case v1 :: v2 :: Nil =>
                Assert.assertTrue(violationCar(v1) == "10");
                Assert.assertTrue(violationCar(v2) == "7")
            case _ => Assert.assertTrue(false)
        }

    /// 15 sub-sectors that cleanly split the 2:00.000 lap into 8000 ms each.
    /// The `_elapsed` column is the running total at each marker.
    def cleanMiniTail(): String =
        "8.000;8.000;8.000;16.000;8.000;24.000" +
        ";8.000;32.000;8.000;40.000;8.000;48.000;8.000;56.000" +
        ";8.000;1:04.000;8.000;1:12.000;8.000;1:20.000;8.000;1:28.000;8.000;1:36.000;8.000;1:44.000;8.000;1:52.000;8.000;2:00.000"

    @Test
    def testMiniSectorsAbsentLapProducesNoMiniViolations(): Unit \ {Assert, IO} =
        // Standard (non-Le Mans) header → miniSectors = None → mini-sector
        // checks must be skipped entirely.
        let lap = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.000", "2:00.000", "14:02:00.000");
        let violations = detect(lap :: Nil);
        Assert.assertTrue(List.isEmpty(List.filter(isMiniSectorSum, violations)));
        Assert.assertTrue(List.isEmpty(List.filter(isMiniSectorMonotonic, violations)))

    @Test
    def testValidLeMansLapProducesNoMiniViolations(): Unit \ {Assert, IO} =
        let lap = buildLeMansLap("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", cleanMiniTail());
        let violations = detect(lap :: Nil);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testMiniSectorSumMismatchDetected(): Unit \ {Assert, IO} =
        // Bump the FL_time from 8.000 → 8.001, leaving lapTime 2:00.000 →
        // sum = 2:00.001, off by 1 ms. Note this also breaks the FL_elapsed
        // monotonic chain so we filter to the SectorSum-style violation.
        let badTail = String.replace({src = "8.000;2:00.000"}, {dst = "8.001;2:00.000"}, cleanMiniTail());
        let lap = buildLeMansLap("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", badTail);
        let violations = detect(lap :: Nil)
            |> List.filter(isMiniSectorSum);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.MiniSectorSum(_, lapMs, sum, _)) =>
                Assert.assertTrue(lapMs == Duration.fromMillis(120000));
                Assert.assertTrue(sum == Duration.fromMillis(120001))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testMiniSectorBlankTimeAnnotated(): Unit \ {Assert, IO} =
        // Blank Z4_time → counted as 0 ms in the sum (8 + 0 + 8 + ... = 1:52.000),
        // so we expect a MiniSectorSum violation with Z4 in the blanks list.
        let badTail = String.replace({src = "8.000;8.000;8.000;16.000"}, {dst = "8.000;8.000;;16.000"}, cleanMiniTail());
        let lap = buildLeMansLap("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", badTail);
        let violations = detect(lap :: Nil)
            |> List.filter(isMiniSectorSum);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.MiniSectorSum(_, _, _, blanks)) =>
                Assert.assertTrue(List.memberOf(MiniSectorId.Z4, blanks))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testMiniSectorElapsedMonotonicViolationDetected(): Unit \ {Assert, IO} =
        // Replace IP1_elapsed (24.000) with 15.000 — strictly less than the
        // previous Z4_elapsed (16.000) — to trigger a backwards step.
        let badTail = String.replace({src = "16.000;8.000;24.000"}, {dst = "16.000;8.000;15.000"}, cleanMiniTail());
        let lap = buildLeMansLap("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", badTail);
        let violations = detect(lap :: Nil)
            |> List.filter(isMiniSectorMonotonic);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.MiniSectorElapsedMonotonic(_, prevId, prevElapsed, currId, currElapsed)) =>
                Assert.assertTrue(prevId == MiniSectorId.Z4);
                Assert.assertTrue(currId == MiniSectorId.IP1);
                Assert.assertTrue(prevElapsed == Duration.fromMillis(16000));
                Assert.assertTrue(currElapsed == Duration.fromMillis(15000))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testMiniSectorElapsedEqualPairFlagged(): Unit \ {Assert, IO} =
        // Two adjacent timing loops cannot physically fire at the same
        // millisecond. Replace IP1_elapsed (24.000) with 16.000 so it
        // matches the previous Z4_elapsed exactly — the strict
        // monotonic check should report this as a violation.
        let badTail = String.replace({src = "16.000;8.000;24.000"}, {dst = "16.000;8.000;16.000"}, cleanMiniTail());
        let lap = buildLeMansLap("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", badTail);
        let violations = detect(lap :: Nil)
            |> List.filter(isMiniSectorMonotonic);
        Assert.assertTrue(List.length(violations) == 1);
        match List.head(violations) {
            case Some(Violation.MiniSectorElapsedMonotonic(_, prevId, prevElapsed, currId, currElapsed)) =>
                Assert.assertTrue(prevId == MiniSectorId.Z4);
                Assert.assertTrue(currId == MiniSectorId.IP1);
                Assert.assertTrue(prevElapsed == currElapsed);
                Assert.assertTrue(prevElapsed == Duration.fromMillis(16000))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testMiniSectorSumSkippedOnBoxedFinishLineLap(): Unit \ {Assert, IO} =
        // Real pit-entry pattern: car crosses FL inside the pit lane
        // (CROSSING_FINISH_LINE_IN_PIT = "B"), bypasses FORDOUT and the
        // FL_time loop. Sum of mini-sector times = 1:44.000 << lapTime
        // = 2:00.000, but we expect NO MiniSectorSum violation because
        // the lap is identified as a pit lap.
        let lap = buildLeMansLapWith("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", pitEntryMiniTail(), "B", "");
        let violations = detect(lap :: Nil)
            |> List.filter(isMiniSectorSum);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testMiniSectorSumSkippedWhenPitTimeRecorded(): Unit \ {Assert, IO} =
        // Even without the boxed-finish-line flag, a recorded PIT_TIME
        // also marks the lap as a pit lap and skips the sum check.
        let lap = buildLeMansLapWith("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", pitEntryMiniTail(), "", "30.500");
        let violations = detect(lap :: Nil)
            |> List.filter(isMiniSectorSum);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testMiniSectorSumStillReportsNonPitLapWithBlankTrailingMarkers(): Unit \ {Assert, IO} =
        // {fordout, fl} blank without any pit or track-limits signal —
        // a genuine timing anomaly (e.g. Le Mans 2025 car 150 lap 14:
        // 4:23.067 lap with FORDOUT and FL_time both blank, no pitTime,
        // no box flag, no track-limits signature). The validator must
        // STILL flag this as a MiniSectorSum violation.
        let lap = buildLeMansLapWith("150", 14, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", pitEntryMiniTail(), "", "");
        let violations = detect(lap :: Nil)
            |> List.filter(isMiniSectorSum);
        Assert.assertTrue(List.length(violations) == 1)

    @Test
    def testMiniSectorSumSkippedOnSCL1FordoutTrackLimits(): Unit \ {Assert, IO} =
        // Track-limits violation at the second Ford chicane: SCL1 and
        // FORDOUT loops are not triggered. No pit signal.
        let lap = buildLeMansLapWith("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", trackLimits_SCL1_FORDOUT_MiniTail(), "", "");
        let violations = detect(lap :: Nil)
            |> List.filter(isMiniSectorSum);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testMiniSectorSumSkippedOnPitrefScl1TrackLimits(): Unit \ {Assert, IO} =
        // Track-limits violation at the first Ford chicane: PITREF and
        // SCL1 loops are not triggered, but the car rejoins before
        // FORDOUT so FORDOUT and FL fire normally.
        let lap = buildLeMansLapWith("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", trackLimits_PITREF_SCL1_MiniTail(), "", "");
        let violations = detect(lap :: Nil)
            |> List.filter(isMiniSectorSum);
        Assert.assertTrue(List.isEmpty(violations))

    @Test
    def testMiniSectorMonotonicStillRunsOnPitLaps(): Unit \ {Assert, IO} =
        // The Monotonic check is independent of pit context: missing
        // markers don't break monotonicity (blank elapsed is skipped),
        // but a backwards step must still be reported even when the lap
        // is a pit lap.
        let badTail = String.replace({src = "16.000;8.000;24.000"}, {dst = "16.000;8.000;15.000"}, pitEntryMiniTail());
        let lap = buildLeMansLapWith("7", 1, "2:00.000", "24.000", "32.000", "64.000", "2:00.000", "14:02:00.000", badTail, "B", "");
        let violations = detect(lap :: Nil);
        Assert.assertTrue(List.isEmpty(List.filter(isMiniSectorSum, violations)));
        Assert.assertTrue(List.length(List.filter(isMiniSectorMonotonic, violations)) == 1)

    @Test
    def testValidateRendersFormattedString(): Unit \ {Assert, IO} =
        // New format: "sector-sum" slug + "expected=...ms... actual=...ms...".
        // elapsed and hour are aligned with lapTime so the formatted output
        // is validated solely against the SectorSum case.
        let lap = buildLap("7", 1, "2:00.000", "30.000", "60.000", "30.001", "2:00.000", "14:02:00.000");
        let messages = validate(lap :: Nil);
        Assert.assertTrue(List.length(messages) == 1);
        match List.head(messages) {
            case Some(msg) =>
                Assert.assertTrue(String.contains({substr = "sector-sum"}, msg));
                Assert.assertTrue(String.contains({substr = "[car 7 #1]"}, msg));
                Assert.assertTrue(String.contains({substr = "expected=2:00.000 (120000ms)"}, msg));
                Assert.assertTrue(String.contains({substr = "actual=2:00.001 (120001ms)"}, msg))
            case None => Assert.assertTrue(false)
        }

}
