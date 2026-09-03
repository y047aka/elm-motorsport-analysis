mod Round.TestTrack {

    use Round.TestRound
    use Round.Summary
    use Motorsport.Calendar.Entry
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Motorsport.Sector.Sector
    use Motorsport.Track
    use Motorsport.Track.Share
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Motorsport.Wec.RawMiniSector
    use Util.Duration
    use Util.HourClock.Hour
    use Util.Json.Encode

    /// Rounds whose ids give `Motorsport.Events` the direction each test is
    /// about. Written out rather than looked up, so a change to the real
    /// calendar cannot quietly rewrite what a test asserts.
    def clockwise(): Entry = { season = 2025, id = "spa_6h", date = "2025-05-09" }

    def counterClockwise(): Entry = { season = 2025, id = "imola_6h", date = "2025-04-19" }

    def unknownDirection(): Entry = { season = 2025, id = "custom_event", date = "2025-01-01" }

    def track(entry: Entry, laps: List[RawLap]): Track.Track \ IO =
        TestRound.onRound(entry, numbered(laps), () -> Summary.read(entry))#track

    /// The fixtures are each written as lap one, which the table's key will not
    /// take twice for the same car. Numbering them changes nothing a share is
    /// read from.
    def numbered(laps: List[RawLap]): List[RawLap] =
        laps |> List.zipWithIndex |> List.map(pair -> match pair {
            case (index, lap) => { lapNumber = index + 1 | lap }
        })

    /// A lap with only the columns the track's proportions are read from; of
    /// the 16, the rest are placeholders.
    def mkLap(lapTime: Int32, s1: Option[Int32], s2: Option[Int32], s3: Option[Int32]): RawLap =
        {
            car = {
                carNumber    = "7",
                class        = "HYPERCAR",
                group        = "H",
                team         = "Toyota",
                manufacturer = "Toyota"
            },
            driver                  = { number = 1, name = "KOBAYASHI" },
            lapNumber               = 1,
            lapTime                 = Duration.fromMillis(lapTime),
            lapImprovement          = Wec.Improvement.None,
            crossingFinishLineInPit = false,
            s1                      = mkSector(s1),
            s2                      = mkSector(s2),
            s3                      = mkSector(s3),
            kph                     = "0",
            elapsed                 = Duration.fromMillis(lapTime),
            hour                    = Hour.Hour(0),
            topSpeed                = "",
            pitTime                 = None,
            flagAtFl                = Wec.Flag.Green,
            miniSectors             = None
        }

    def mkSector(ms: Option[Int32]): Wec.RawSector =
        { value = Option.map(Duration.fromMillis, ms), improvement = Wec.Improvement.None }

    /// Gives every mini-sector the same time, which makes a sector's share of
    /// the lap its count of mini-sectors -- 3, 4 and 8 of the 15.
    def withEvenMiniSectors(each: Int32, lap: RawLap): RawLap =
        withMiniSectors(_ -> Some(each), lap)

    def withMiniSectors(timeOf: MiniSectorId -> Option[Int32], lap: RawLap): RawLap =
        let entries = MiniSector.all() |> List.map(id ->
            (id, ({ time = Option.map(Duration.fromMillis, timeOf(id)), elapsed = None }: RawMiniSector))
        );
        { miniSectors = Some(entries) | lap }

    def shareOf(sector: Sector, track: Track.Track): Option[Share] =
        track#sectors |> List.findLeft(match (other, _) -> other == sector) |> Option.map(match (_, share) -> share)

    def miniShareOf(id: MiniSectorId, track: Track.Track): Option[Share] =
        track#miniSectors
            |> Option.flatMap(list -> List.findLeft(match (other, _) -> other == id, list))
            |> Option.map(match (_, share) -> share)

    def closeTo(expected: Float64, actual: Float64): Bool =
        Float64.abs(expected - actual) < 0.000001f64

    def isShare(start: Float64, share: Float64, actual: Option[Share]): Bool =
        match actual {
            case None    => false
            case Some(s) => closeTo(start, s#start) and closeTo(share, s#share)
        }

    @Test
    def testRecordIsTheQuickestOfEveryLapNotTheFirst(): Unit \ {Assert, IO} =
        let laps =
            mkLap(200000, Some(80000), Some(60000), Some(60000)) ::
            mkLap(100000, Some(20000), Some(30000), Some(50000)) ::
            Nil;
        let track = track(clockwise(), laps);
        Assert.assertTrue(isShare(0.0f64, 0.2f64, shareOf(Sector.S1, track)))

    @Test
    def testStretchWithNoTimeTakesNoShare(): Unit \ {Assert, IO} =
        // S2 was never recorded, so S3 starts where S1 left off and the lap is
        // still divided in full.
        let laps = mkLap(50000, Some(20000), None, Some(30000)) :: Nil;
        let track = track(clockwise(), laps);
        Assert.assertTrue(isShare(0.0f64, 0.4f64, shareOf(Sector.S1, track)));
        Assert.assertTrue(isShare(0.4f64, 0.0f64, shareOf(Sector.S2, track)));
        Assert.assertTrue(isShare(0.4f64, 0.6f64, shareOf(Sector.S3, track)))

    @Test
    def testNoRecordsAtAllDividesTheLapEvenly(): Unit \ {Assert, IO} =
        // Nothing is known about how long each stretch is until a lap has been
        // round, whether the file holds a blank lap or no laps at all.
        List#{mkLap(0, None, None, None) :: Nil, Nil} |> List.forEach(laps -> {
            let track = track(unknownDirection(), laps);
            Assert.assertTrue(isShare(0.0f64, 1.0f64 / 3.0f64, shareOf(Sector.S1, track)));
            Assert.assertTrue(isShare(2.0f64 / 3.0f64, 1.0f64 / 3.0f64, shareOf(Sector.S3, track)));
            Assert.assertTrue(Option.isEmpty(track#miniSectors))
        })

    @Test
    def testMiniSectorsOfALapWithNoLapTimeAreNotRecords(): Unit \ {Assert, IO} =
        // The first lap has no lap time -- the feed writes 0.000 -- so its
        // impossibly quick SCL2 does not take the record from the second.
        let laps =
            withMiniSectors(id -> if (id == MiniSectorId.SCL2) Some(1) else Some(1000), mkLap(0, None, None, None)) ::
            withEvenMiniSectors(1000, mkLap(15000, None, None, None)) ::
            Nil;
        let track = track(clockwise(), laps);
        Assert.assertTrue(isShare(0.0f64, 1.0f64 / 15.0f64, miniShareOf(MiniSectorId.SCL2, track)))

    @Test
    def testOneRoundWithMiniSectorsPutsEveryLapAtThatGrain(): Unit \ {Assert, IO} =
        let laps =
            mkLap(15000, Some(1000), Some(1000), Some(1000)) ::
            withEvenMiniSectors(1000, mkLap(15000, Some(1000), Some(1000), Some(1000))) ::
            Nil;
        let track = track(clockwise(), laps);
        Assert.assertTrue(isShare(0.0f64, 3.0f64 / 15.0f64, shareOf(Sector.S1, track)))

    @Test
    def testToJsonRendersExpectedKeys(): Unit \ {Assert, IO} =
        let laps = withEvenMiniSectors(1000, mkLap(15000, Some(1000), Some(1000), Some(1000))) :: Nil;
        let json = Encode.render(Track.toJson(track(clockwise(), laps)));
        Assert.assertTrue(String.contains({substr = "\"sectors\""}, json));
        Assert.assertTrue(String.contains({substr = "\"s1\""}, json));
        Assert.assertTrue(String.contains({substr = "\"start\""}, json));
        Assert.assertTrue(String.contains({substr = "\"share\""}, json));
        Assert.assertTrue(String.contains({substr = "\"miniSectors\""}, json));
        Assert.assertTrue(String.contains({substr = "\"scl2\""}, json));
        Assert.assertTrue(String.contains({substr = "\"fl\""}, json))

    @Test
    def testDirectionIsWrittenOutAsGiven(): Unit \ {Assert, IO} =
        let laps = mkLap(100000, Some(20000), Some(30000), Some(50000)) :: Nil;
        let json = Encode.render(Track.toJson(track(counterClockwise(), laps)));
        Assert.assertTrue(String.contains({substr = "\"direction\": \"counter_clockwise\""}, json))

    @Test
    def testCircuitOfUnknownDirectionSaysNothing(): Unit \ {Assert, IO} =
        let laps = mkLap(100000, Some(20000), Some(30000), Some(50000)) :: Nil;
        let json = Encode.render(Track.toJson(track(unknownDirection(), laps)));
        Assert.assertTrue(not String.contains({substr = "\"direction\""}, json))

    @Test
    def testRoundWithoutMiniSectorsOmitsThem(): Unit \ {Assert, IO} =
        let laps = mkLap(100000, Some(20000), Some(30000), Some(50000)) :: Nil;
        let json = Encode.render(Track.toJson(track(clockwise(), laps)));
        Assert.assertTrue(not String.contains({substr = "\"miniSectors\""}, json))

}
