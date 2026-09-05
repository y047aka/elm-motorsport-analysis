mod Round.TestIndex {

    use Round.Index
    use Round.TestSupport
    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use Motorsport.Calendar.Entry
    use Motorsport.Index.Change
    use Motorsport.Index.Record
    use Motorsport.MiniSector.MiniSectorId
    use Motorsport.Sector.Sector
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    def entry(): Entry = { season = 2025, id = "test", date = "2025-01-01" }

    def indexOf(laps: List[RawLap]): Motorsport.Index.Index \ IO =
        TestSupport.onRound(entry(), laps, () -> Index.read(entry()))

    def changesOf(record: Record, laps: List[RawLap]): List[Change] \ IO =
        Motorsport.Index.changesOf(record, indexOf(laps))

    /// `(time, car number, lap)`, which is what a test is asserting about a
    /// change: the record, and who took it.
    def held(changes: List[Change]): List[(String, String, Int32)] =
        changes |> List.map(c -> (Util.Duration.format(c#time), c#carNumber, c#lap))

    // ---------------------------------------------------------------- laps

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    def miniHeader(): String =
        header() + ";SCL2_time;SCL2_elapsed"

    def decodeOne(csv: String): RawLap =
        match Decode.decodeCustom({fieldSeparator = ';'}, FieldNames.FieldNamesFromFirstRow, Wec.decoder(), csv) {
            case Ok(lap :: _) => lap
            case _            => unreachable!()
        }

    /// One lap, with the three sector times summing to the lap time so that
    /// nothing about the row has to be believed twice.
    def lap(num: String, driver: String, lapNumber: Int32, lapTime: String, s1: String, s2: String, s3: String, elapsed: String): RawLap =
        decodeOne(header() + "\n"
            + "${num};1;${lapNumber};${lapTime};0;;${s1};0;${s2};0;${s3};0;100;${elapsed};11:00:00.000;0:${s1};0:${s2};0:${s3};200;${driver};;HYPERCAR;H;Team;Maker;GF;${s1};${s2};${s3};")

    /// The same, with the round's one mini-sector marker recorded.
    def miniLap(num: String, lapNumber: Int32, lapTime: String, elapsed: String, scl2: String): RawLap =
        decodeOne(miniHeader() + "\n"
            + "${num};1;${lapNumber};${lapTime};0;;20.000;0;20.000;0;20.000;0;100;${elapsed};11:00:00.000;0:20.000;0:20.000;0:20.000;200;Driver;;HYPERCAR;H;Team;Maker;GF;20.000;20.000;20.000;${scl2};${scl2}")

    // ------------------------------------------------------ lap completions

    /// The counter goes up when the first car of the field crosses the line,
    /// so the lap it reads is the earliest of the laps carrying that number.
    @Test
    def theCounterFollowsTheLeader(): Unit \ {Assert, IO} =
        let laps =
            lap("7", "Driver A", 1, "60.000", "20.000", "20.000", "20.000", "60.000") ::
            lap("8", "Driver B", 1, "62.000", "20.000", "21.000", "21.000", "62.000") ::
            lap("8", "Driver B", 2, "61.000", "20.000", "20.500", "20.500", "2:03.000") ::
            lap("7", "Driver A", 2, "64.000", "22.000", "21.000", "21.000", "2:04.000") ::
            Nil;
        let completions = indexOf(laps)#lapCompletions
            |> List.map(match (n, elapsed) -> (n, Util.Duration.format(elapsed)));
        Assert.assertTrue(completions == (1, "1:00.000") :: (2, "2:03.000") :: Nil)

    // ---------------------------------------------------------- best times

    /// A record is only a change where it was beaten: a lap slower than the
    /// standing time leaves it where it was.
    @Test
    def onlyAnImprovementChangesTheRecord(): Unit \ {Assert, IO} =
        let laps =
            lap("7", "Driver A", 1, "60.000", "20.000", "20.000", "20.000", "60.000") ::
            lap("8", "Driver B", 1, "61.000", "21.000", "20.000", "20.000", "61.000") ::
            lap("8", "Driver B", 2, "58.000", "19.000", "19.500", "19.500", "1:59.000") ::
            Nil;
        Assert.assertTrue(
            held(changesOf(Record.FastestLap, laps))
                == ("1:00.000", "7", 1) :: ("58.000", "8", 2) :: Nil
        )

    /// The slowest lap is the same walk in the other direction, which is the
    /// one record a running minimum does not find.
    @Test
    def theSlowestLapIsWonTheOtherWayRound(): Unit \ {Assert, IO} =
        let laps =
            lap("7", "Driver A", 1, "60.000", "20.000", "20.000", "20.000", "60.000") ::
            lap("8", "Driver B", 1, "61.000", "21.000", "20.000", "20.000", "61.000") ::
            lap("8", "Driver B", 2, "58.000", "19.000", "19.500", "19.500", "1:59.000") ::
            Nil;
        Assert.assertTrue(
            held(changesOf(Record.SlowestLap, laps))
                == ("1:00.000", "7", 1) :: ("1:01.000", "8", 1) :: Nil
        )

    /// A sector record is the sector's own time, not the time of the lap that
    /// set it -- and it is won on a lap that took neither of the others.
    @Test
    def aSectorRecordIsItsOwnTime(): Unit \ {Assert, IO} =
        let laps =
            lap("7", "Driver A", 1, "60.000", "20.000", "20.000", "20.000", "60.000") ::
            lap("8", "Driver B", 1, "61.000", "19.000", "21.000", "21.000", "61.000") ::
            Nil;
        Assert.assertTrue(
            held(changesOf(Record.FastestSector(Sector.S1), laps))
                == ("20.000", "7", 1) :: ("19.000", "8", 1) :: Nil
        );
        Assert.assertTrue(held(changesOf(Record.FastestSector(Sector.S2), laps)) == ("20.000", "7", 1) :: Nil)

    /// The feed writes a lap it did not record as `0.000`. That is not a lap
    /// of the circuit, so it takes no record however fast it reads.
    @Test
    def anUnrecordedLapTimeTakesNoRecord(): Unit \ {Assert, IO} =
        let laps =
            lap("7", "Driver A", 1, "0.000", "20.000", "20.000", "20.000", "60.000") ::
            lap("8", "Driver B", 1, "61.000", "21.000", "20.000", "20.000", "61.000") ::
            Nil;
        Assert.assertTrue(held(changesOf(Record.FastestLap, laps)) == ("1:01.000", "8", 1) :: Nil);
        Assert.assertTrue(held(changesOf(Record.SlowestLap, laps)) == ("1:01.000", "8", 1) :: Nil)

    /// Nor are the mini-sectors of such a lap, which the feed records all the
    /// same.
    @Test
    def theMiniSectorsOfAnUnrecordedLapTakeNoRecord(): Unit \ {Assert, IO} =
        let laps =
            miniLap("7", 1, "0.000", "60.000", "10.000") ::
            miniLap("8", 1, "60.000", "61.000", "18.000") ::
            Nil;
        Assert.assertTrue(
            held(changesOf(Record.FastestMiniSector(MiniSectorId.SCL2), laps))
                == ("18.000", "8", 1) :: Nil
        )

    /// A round whose feed splits the lap no further has every mini-sector
    /// record empty rather than missing.
    @Test
    def aRoundWithoutMiniSectorsHasThemAllEmpty(): Unit \ {Assert, IO} =
        let index = indexOf(lap("7", "Driver A", 1, "60.000", "20.000", "20.000", "20.000", "60.000") :: Nil);
        Assert.assertTrue(List.length(index#bestTimes) == List.length(Motorsport.Index.records()));
        Assert.assertTrue(
            Motorsport.MiniSector.all()
                |> List.forAll(m -> List.isEmpty(Motorsport.Index.changesOf(Record.FastestMiniSector(m), index)))
        )

    /// A round the rows hold none of reads as a race that never ran, which is
    /// what `Round.Laps.loaded` is asked before any of this is rendered.
    @Test
    def aRoundWithNoLapsHasNoIndex(): Unit \ {Assert, IO} =
        let index = indexOf(Nil);
        Assert.assertTrue(List.isEmpty(index#lapCompletions));
        Assert.assertTrue(List.isEmpty(Motorsport.Index.changesOf(Record.FastestLap, index)))

}
