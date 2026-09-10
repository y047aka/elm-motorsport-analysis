mod Round.TestTimeline {

    use Round.TestSupport
    use Round.Timeline
    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use Util.Duration.Duration
    use Motorsport.Calendar.Entry
    use Motorsport.Timeline.CarEvent
    use Motorsport.Timeline.Event
    use Motorsport.Timeline.EventType
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    def entry(): Entry = { season = 2025, id = "test", date = "2025-01-01" }

    /// The counting and the weighing, asked of the laps rather than of the rows
    /// the load wrote: the time limit a test is about is its own, and a load
    /// derives that one from the laps.
    def timelineOf(timeLimit: String, laps: List[RawLap]): List[Event] \ IO =
        TestSupport.onRound(entry(), laps, () -> Timeline.fromLaps(entry(), duration(timeLimit)))

    def duration(s: String): Duration =
        match Util.Duration.fromString(s) {
            case Some(d) => d
            case None    => unreachable!()
        }

    /// `(when, what, whose)`, which is what a test is asserting about an event.
    /// The race start is nobody's, and reads back with an empty car number.
    def shape(event: Event): (String, String, String) =
        let when = Util.Duration.format(event#elapsed);
        match event#eventType {
            case EventType.RaceStart => (when, "raceStart", "")
            case EventType.Of(carNumber, carEvent) => (when, name(carEvent), carNumber)
        }

    def name(carEvent: CarEvent): String =
        match carEvent {
            case CarEvent.Start        => "start"
            case CarEvent.TookLead     => "tookLead"
            case CarEvent.PitIn(_, _)  => "pitIn"
            case CarEvent.PitOut(_, _) => "pitOut"
            case CarEvent.Retirement   => "retirement"
            case CarEvent.Checkered    => "checkered"
        }

    def named(what: String, events: List[Event]): List[(String, String, String)] =
        events |> List.map(shape) |> List.filter(match (_, kind, _) -> kind == what)

    /// `(lap, length)` per half of a stop, which is what only a stop carries.
    def stops(events: List[Event]): List[(Int32, String)] =
        events |> List.filterMap(event -> match event#eventType {
            case EventType.Of(_, CarEvent.PitIn(lap_, length))  => Some((lap_, Util.Duration.format(length)))
            case EventType.Of(_, CarEvent.PitOut(lap_, length)) => Some((lap_, Util.Duration.format(length)))
            case _                                              => None
        })

    // ---------------------------------------------------------------- laps

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    def decodeOne(csv: String): RawLap =
        match Decode.decodeCustom({fieldSeparator = ';'}, FieldNames.FieldNamesFromFirstRow, Wec.decoder(), csv) {
            case Ok(lap :: _) => lap
            case _            => unreachable!()
        }

    def lap(num: String, lapNumber: Int32, elapsed: String): RawLap =
        pitLap(num, lapNumber, elapsed, "")

    /// The same lap, with the time the car spent in the pits on it.
    def pitLap(num: String, lapNumber: Int32, elapsed: String, pit: String): RawLap =
        decodeOne(header() + "\n"
            + "${num};1;${lapNumber};60.000;0;;20.000;0;20.000;0;20.000;0;100;${elapsed};11:00:00.000;"
            + "0:20.000;0:20.000;0:20.000;200;Driver;${pit};HYPERCAR;H;Team;Maker;GF;20.000;20.000;20.000;")

    // --------------------------------------------------------------- starts

    /// One per car that turned a lap, and the race's own start beside them.
    @Test
    def everyCarThatTookTheStartIsOne(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            Nil);
        Assert.assertTrue(named("raceStart", events) == ("0.000", "raceStart", "") :: Nil);
        Assert.assertTrue(named("start", events) ==
            ("0.000", "start", "7") ::
            ("0.000", "start", "8") :: Nil)

    // ------------------------------------------------------------ terminals

    /// The flag falls on a car still running when the race was scheduled to
    /// end; a car whose last lap fell short of that had stopped.
    @Test
    def theFlagFallsOnWhoeverWasStillRunning(): Unit \ {Assert, IO} =
        let events = timelineOf("2:00.000",
            lap("7", 1, "60.000") ::
            lap("7", 2, "2:01.000") ::
            lap("8", 1, "62.000") ::
            Nil);
        Assert.assertTrue(named("checkered", events) == ("2:01.000", "checkered", "7") :: Nil);
        Assert.assertTrue(named("retirement", events) == ("1:02.000", "retirement", "8") :: Nil)

    // ---------------------------------------------------------------- stops

    /// A stop is read off the lap it ended on: the car came out when that lap
    /// was completed, and went in the stop's length before that.
    @Test
    def aStopIsTheLapItEndedOn(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            pitLap("7", 2, "3:00.000", "1:10.000") ::
            Nil);
        Assert.assertTrue(named("pitIn", events) == ("1:50.000", "pitIn", "7") :: Nil);
        Assert.assertTrue(named("pitOut", events) == ("3:00.000", "pitOut", "7") :: Nil)

    /// Which lap it was and how long it took ride on both halves of it.
    @Test
    def aStopCarriesItsLapAndItsLength(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            pitLap("7", 4, "3:00.000", "1:10.000") :: Nil);
        Assert.assertTrue(stops(events) == (4, "1:10.000") :: (4, "1:10.000") :: Nil)

    /// A stop longer than the race was old when it ended went in before the
    /// start, and the start is what it reads back as: a moment before the race
    /// began is not one, and written out it would be a time nothing parses.
    @Test
    def aStopReachingBackPastTheStartBeginsAtIt(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            pitLap("7", 1, "1:00.000", "1:10.000") :: Nil);
        Assert.assertTrue(named("pitIn", events) == ("0.000", "pitIn", "7") :: Nil)

    /// A lap the car did not stop on is not a stop.
    @Test
    def aLapWithNoPitTimeIsNoStop(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000", lap("7", 1, "60.000") :: Nil);
        Assert.assertTrue(named("pitIn", events) == Nil);
        Assert.assertTrue(named("pitOut", events) == Nil)

    // ---------------------------------------------------------------- leads

    /// The lead is who crossed the line first on a lap, and an event each time
    /// that changes hands.
    @Test
    def oneEventPerChangeOfTheLead(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            lap("8", 2, "2:03.000") ::
            lap("7", 2, "2:04.000") ::
            lap("7", 3, "3:00.000") ::
            lap("8", 3, "3:05.000") ::
            Nil);
        Assert.assertTrue(named("tookLead", events) ==
            ("2:03.000", "tookLead", "8") ::
            ("3:00.000", "tookLead", "7") :: Nil)

    /// Whoever led the opening lap took it from nobody.
    @Test
    def theOpeningLeaderTookItFromNobody(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            Nil);
        Assert.assertTrue(named("tookLead", events) == Nil)

    /// A field that never changes leader produces none at all.
    @Test
    def aFieldWithOneLeaderThroughoutProducesNone(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            lap("7", 2, "2:00.000") ::
            lap("8", 2, "2:02.000") ::
            Nil);
        Assert.assertTrue(named("tookLead", events) == Nil)

    // ---------------------------------------------------------------- order

    @Test
    def theTimelineComesBackInTimeOrder(): Unit \ {Assert, IO} =
        let events = timelineOf("2:00.000",
            lap("7", 1, "60.000") ::
            pitLap("7", 2, "2:30.000", "30.000") ::
            lap("8", 1, "62.000") ::
            lap("8", 2, "2:20.000") ::
            Nil);
        let times = events |> List.map(event -> event#elapsed);
        Assert.assertTrue(times == List.sort(times))

    /// Two events landing on one instant come back in the order the phases are
    /// gathered in, so the round is written the same way twice.
    @Test
    def aStopEndingAtTheFlagIsOvertakenByIt(): Unit \ {Assert, IO} =
        let events = timelineOf("2:00.000",
            lap("7", 1, "60.000") ::
            pitLap("7", 2, "2:30.000", "30.000") ::
            Nil);
        Assert.assertTrue(events |> List.map(shape) ==
            ("0.000", "raceStart", "") ::
            ("0.000", "start", "7") ::
            ("2:00.000", "pitIn", "7") ::
            ("2:30.000", "pitOut", "7") ::
            ("2:30.000", "checkered", "7") :: Nil)


    // ----------------------------------------------------------------- rows

    /// The timeline the load wrote, and the one it counted to write it.
    ///
    /// The laps run past the hour so that the limit a load derives falls inside
    /// them, which is what puts the flag on one car and a retirement on the
    /// other: `Motorsport.Metadata` reads the limit as the whole hours the
    /// round's longest run covered.
    def loadedAndCounted(): (List[Event], List[Event]) \ IO =
        let laps =
            lap("7", 1, "30:00.000") ::
            lap("8", 1, "31:00.000") ::
            lap("8", 2, "50:00.000") ::
            pitLap("7", 2, "1:00:00.000", "1:10.000") ::
            lap("7", 3, "1:30:00.000") ::
            Nil;
        TestSupport.onRound(entry(), laps, () -> (
            Timeline.read(entry()),
            Timeline.fromLaps(entry(), Round.Summary.particulars(entry())#timeLimit)
        ))

    @Test
    def theRowsReadBackAsTheTimelineTheLoadCounted(): Unit \ {Assert, IO} =
        match loadedAndCounted() {
            case (readBack, counted) =>
                Assert.assertTrue(List.map(shape, readBack) == List.map(shape, counted))
        }

    /// Every kind of event comes back through a row, the two things only a stop
    /// carries included.
    @Test
    def everyKindOfEventComesBackThroughARow(): Unit \ {Assert, IO} =
        match loadedAndCounted() {
            case (readBack, _) =>
                Assert.assertTrue(named("raceStart", readBack) == ("0.000", "raceStart", "") :: Nil);
                Assert.assertTrue(named("start", readBack) ==
                    ("0.000", "start", "7") ::
                    ("0.000", "start", "8") :: Nil);
                Assert.assertTrue(named("tookLead", readBack) ==
                    ("50:00.000", "tookLead", "8") ::
                    ("1:30:00.000", "tookLead", "7") :: Nil);
                Assert.assertTrue(named("checkered", readBack) == ("1:30:00.000", "checkered", "7") :: Nil);
                Assert.assertTrue(named("retirement", readBack) == ("50:00.000", "retirement", "8") :: Nil);
                Assert.assertTrue(stops(readBack) == (2, "1:10.000") :: (2, "1:10.000") :: Nil)
        }

}
