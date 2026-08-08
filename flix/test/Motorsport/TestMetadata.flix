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
    def testToJsonRendersExpectedKeys(): Unit \ Assert =
        let laps = withS1("29.100", mkLap("7", 1, "1:33.291", "KOBAYASHI", "HYPERCAR", "H", "Toyota", "Toyota")) :: Nil;
        let meta = Metadata.fromRawLaps("le_mans_24h", laps);
        let json = Encode.render(Metadata.toJson(meta));
        // Asserts the shape: that the keys are present.
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
