mod Motorsport.TestMetadata {

    use Motorsport.Metadata
    use Motorsport.Metadata.Basis
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Util.Duration
    use Util.HourClock.Hour
    use Util.Json.Encode

    /// Builds a RawLap with only the columns a test needs filled in; of the 22,
    /// the rest are placeholders.
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

    /// Gives a lap the time of day it crossed the line at; `mkLap` leaves every
    /// lap at midnight, which would put every race's start at minus its elapsed.
    def withHour(hour: String, lap: RawLap): RawLap =
        { hour = mkHour(hour) | lap }

    def mkHour(raw: String): Hour =
        match Util.HourClock.parse(raw) {
            case Ok(h)  => h
            case Err(_) => Hour.Hour(0)
        }

    def mkDuration(raw: String): Duration.Duration =
        Duration.fromString(raw) |> Option.getWithDefault(Duration.zero())

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
        // 12 leads on S1, but 7 was first to finish the lap. The CSV order
        // (7, 12) does not survive either.
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
        // A feed with no S1 is read by lap-1 elapsed, and basis says so.
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
        // One car short of an S1 puts every readable car on elapsed. #7's S1
        // (1:10) is under #12's elapsed (1:35), but the two are not compared.
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
        // #99 turned no first lap, so it has no say in the choice and does not
        // take the other two cars' S1 down with it.
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
        // All three share an S1. 7 comes out on top on elapsed; 9 and 10 tie
        // there too, so the car number settles it, as strings: "10" before "9".
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
        // Placed at the back rather than dropped. Car number 1 sorts under 7 and
        // still does not pass a car that could be read.
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
        // Positions still fill 1..n when no car can be read.
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
    def testRaceRanAsFarAsTheLastLapTaken(): Unit \ Assert =
        // The last car home did 2:30:00, so a two-hour race ran half an hour
        // over -- which is the ordinary way a timed race ends, on the lap in
        // progress when the flag falls.
        let laps =
            mkLap("7",  1, "1:33.291",    "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota") ::
            mkLap("12", 3, "2:30:00.000", "STEVENS",   "HYPERCAR", "H", "Hertz",  "Porsche") ::
            mkLap("7",  2, "2:29:00.000", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota") ::
            Nil;
        let race = Metadata.fromRawLaps("fuji_6h", laps)#race;
        Assert.assertTrue(race#duration == mkDuration("2:30:00.000"));
        Assert.assertTrue(race#timeLimit == mkDuration("2:00:00.000"));
        Assert.assertTrue(race#lapTotal == 3)

    @Test
    def testStartedAtIsHourLessElapsed(): Unit \ Assert =
        // Fuji 2025's opening lap: crossed the line at 11:02:32.086 having
        // taken 1:35.343 to get there.
        let laps =
            withHour("11:02:32.086", mkLap("7", 1, "1:35.343", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) ::
            Nil;
        let race = Metadata.fromRawLaps("fuji_6h", laps)#race;
        Assert.assertTrue(race#startedAt == Some(mkHour("11:00:56.743")))

    @Test
    def testStartedAtSurvivesMidnight(): Unit \ Assert =
        // Le Mans starts at 16:00 and runs past midnight, so hour wraps while
        // elapsed keeps growing: a lap done at 02:00 is ten hours in.
        let laps =
            withHour("02:00:00.000", mkLap("7", 300, "10:00:00.000", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) ::
            Nil;
        let race = Metadata.fromRawLaps("le_mans_24h", laps)#race;
        Assert.assertTrue(race#startedAt == Some(mkHour("16:00:00.000")))

    @Test
    def testNoLapsLeavesTheRaceUnread(): Unit \ Assert =
        let race = Metadata.fromRawLaps("fuji_6h", Nil)#race;
        Assert.assertTrue(race#startedAt == None);
        Assert.assertTrue(race#duration == Duration.zero());
        Assert.assertTrue(race#timeLimit == Duration.zero());
        Assert.assertTrue(race#lapTotal == 0)

    @Test
    def testUnreadStartIsOmittedRatherThanMidnight(): Unit \ Assert =
        let json = Encode.render(Metadata.toJson(Metadata.fromRawLaps("fuji_6h", Nil)));
        Assert.assertTrue(not String.contains({substr = "\"startedAt\""}, json))

    @Test
    def testToJsonRendersExpectedKeys(): Unit \ Assert =
        let laps = withHour("16:01:33.291", withS1("29.100", mkLap("7", 1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota"))) :: Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        let json = Encode.render(Metadata.toJson(meta));
        // Asserts the shape: that the keys are present.
        Assert.assertTrue(String.contains({substr = "\"name\""}, json));
        Assert.assertTrue(String.contains({substr = "\"24 Hours of Le Mans\""}, json));
        Assert.assertTrue(String.contains({substr = "\"race\""}, json));
        Assert.assertTrue(String.contains({substr = "\"startedAt\": \"16:00:00.000\""}, json));
        Assert.assertTrue(String.contains({substr = "\"duration\": \"1:33.291\""}, json));
        Assert.assertTrue(String.contains({substr = "\"timeLimit\": \"0.000\""}, json));
        Assert.assertTrue(String.contains({substr = "\"lapTotal\": 1"}, json));
        Assert.assertTrue(String.contains({substr = "\"startingGrid\""}, json));
        Assert.assertTrue(String.contains({substr = "\"basis\": \"lap1_s1\""}, json));
        Assert.assertTrue(String.contains({substr = "\"entries\""}, json));
        Assert.assertTrue(String.contains({substr = "\"position\": 1"}, json));
        Assert.assertTrue(String.contains({substr = "\"carNumber\""}, json));
        Assert.assertTrue(String.contains({substr = "\"drivers\""}, json));
        Assert.assertTrue(String.contains({substr = "\"name\": \"KOBAYASHI\""}, json));
        Assert.assertTrue(String.contains({substr = "\"manufacturer\": \"Toyota\""}, json))

}
