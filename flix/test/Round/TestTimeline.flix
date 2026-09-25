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

    /// Asked of the laps rather than of the rows the load wrote: the time limit
    /// a test is about is its own, and a load derives that one from the laps.
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
            case CarEvent.TookLeadOnTrack => "tookLeadOnTrack"
            case CarEvent.LeaderPitted    => "leaderPitted"
            case CarEvent.Retirement      => "retirement"
            case CarEvent.Checkered       => "checkered"
        }

    def named(what: String, events: List[Event]): List[(String, String, String)] =
        events |> List.map(shape) |> List.filter(match (_, kind, _) -> kind == what)

    /// Either of the two events a change of the lead is worth, which is what a test
    /// asking whether the lead changed hands at all is asking about.
    def leadChanges(events: List[Event]): List[(String, String, String)] =
        events |> List.map(shape)
            |> List.filter(match (_, kind, _) ->
                List.memberOf(kind, leadNames()))

    def leadNames(): List[String] =
        "tookLeadOnTrack" :: "leaderPitted" :: Nil

    // ---------------------------------------------------------------- laps

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    def decodeOne(csv: String): RawLap =
        match Decode.decodeCustom({fieldSeparator = ';'}, FieldNames.FieldNamesFromFirstRow, Wec.decoder(), csv) {
            case Ok(lap :: _) => lap
            case _            => unreachable!()
        }

    def lap(num: String, lapNumber: Int32, elapsed: String): RawLap =
        crossing(num, lapNumber, elapsed, "", "")

    /// The lap a car came back out on, which is the one the stop's length is
    /// written on.
    def pitLap(num: String, lapNumber: Int32, elapsed: String, pit: String): RawLap =
        crossing(num, lapNumber, elapsed, "", pit)

    /// The lap a car turned down the pit lane at the end of, which the feed marks
    /// with the box and writes no time on.
    def boxLap(num: String, lapNumber: Int32, elapsed: String): RawLap =
        crossing(num, lapNumber, elapsed, "B", "")

    def crossing(
        num: String,
        lapNumber: Int32,
        elapsed: String,
        box: String,
        pit: String
    ): RawLap =
        decodeOne(header() + "\n"
            + "${num};1;${lapNumber};60.000;0;${box};20.000;0;20.000;0;20.000;0;100;${elapsed};11:00:00.000;"
            + "0:20.000;0:20.000;0:20.000;200;Driver;${pit};HYPERCAR;H;Team;Maker;GF;20.000;20.000;20.000;")

    // ------------------------------------------------------------ race start

    /// One event at nought, the race's own: no row per car sits beside it.
    @Test
    def theRaceStartIsTheOnlyEventAtNought(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            Nil);
        Assert.assertTrue(events
            |> List.filter(event -> event#elapsed == Util.Duration.zero())
            |> List.map(shape) == ("0.000", "raceStart", "") :: Nil)

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

    // ---------------------------------------------------------------- leads

    /// The lead is who crossed the line first on a lap, and an event each time
    /// that changes hands. Nobody of this field stopped, so each change was taken
    /// on track.
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
        Assert.assertTrue(leadChanges(events) ==
            ("2:03.000", "tookLeadOnTrack", "8") ::
            ("3:00.000", "tookLeadOnTrack", "7") :: Nil)

    /// A change the leader's stop settled is about the leader and not about who
    /// went in front. With no in-lap written, it is timed at the out-lap, the one
    /// crossing of the stop there is.
    @Test
    def aLeadTheLeaderGaveUpInThePits(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            lap("8", 2, "2:00.000") ::
            pitLap("7", 2, "2:40.000", "40.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) == ("2:40.000", "leaderPitted", "7") :: Nil)

    /// A stop written over its two crossings is timed at the in-lap, where the car
    /// turned down the lane, and the change of the lead the stop settled is no event:
    /// whoever stayed out passed no one. Taking the lead back a lap later is a pass.
    @Test
    def aLeadTheLeaderLostByTurningIntoThePits(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            lap("8", 2, "2:00.000") ::
            boxLap("7", 2, "2:01.000") ::
            pitLap("7", 3, "2:45.000", "44.000") ::
            lap("8", 3, "3:00.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) ==
            ("2:01.000", "leaderPitted", "7") ::
            ("2:45.000", "tookLeadOnTrack", "7") ::
            Nil)

    /// The case the lead says nothing about: the leader came in and came back out in
    /// front of the field, so no lap boundary changed hands and there is no pass to
    /// hang the stop on. Seven of Le Mans's leader stops are this, and the event is
    /// timed at where the car turned down the lane.
    @Test
    def aLeaderThatCameInAndStayedLeaderIsAnEvent(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "70.000") ::
            lap("7", 2, "2:00.000") ::
            lap("8", 2, "2:20.000") ::
            boxLap("7", 3, "3:00.000") ::
            lap("8", 3, "3:30.000") ::
            pitLap("7", 4, "4:10.000", "45.000") ::
            lap("8", 4, "4:40.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) == ("3:00.000", "leaderPitted", "7") :: Nil)

    /// A leader that came back out in front and was passed on the lap after its
    /// out-lap lost the lead on the track: its crossing of that lap is not in the
    /// pit lane, whatever the lap before it was.
    @Test
    def aLeaderPassedTheLapAfterItsOutLapLostItOnTrack(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "70.000") ::
            lap("7", 2, "2:00.000") ::
            lap("8", 2, "2:20.000") ::
            boxLap("7", 3, "3:00.000") ::
            lap("8", 3, "3:30.000") ::
            pitLap("7", 4, "4:10.000", "45.000") ::
            lap("8", 4, "4:40.000") ::
            lap("8", 5, "5:30.000") ::
            lap("7", 5, "5:35.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) ==
            ("3:00.000", "leaderPitted", "7") ::
            ("5:30.000", "tookLeadOnTrack", "8") ::
            Nil)

    /// A stop by a car that was never in the lead is not a leader's stop: it led
    /// neither the lap before its out-lap nor the lap before that.
    @Test
    def aStopByACarThatNeverLedIsNoEvent(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "70.000") ::
            lap("7", 2, "2:00.000") ::
            boxLap("8", 2, "2:20.000") ::
            lap("7", 3, "3:00.000") ::
            pitLap("8", 3, "3:20.000", "45.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) == Nil)

    /// Whoever led the opening lap took it from nobody.
    @Test
    def theOpeningLeaderTookItFromNobody(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) == Nil)

    /// A field that never changes leader produces none at all.
    @Test
    def aFieldWithOneLeaderThroughoutProducesNone(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            lap("7", 2, "2:00.000") ::
            lap("8", 2, "2:02.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) == Nil)

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


    // ----------------------------------------------------------------- rows

    /// The timeline the load wrote, and the one it counted to write it.
    ///
    /// The laps run past the hour so that the limit a load derives falls inside
    /// them -- `Motorsport.Metadata` reads it as the whole hours the round's
    /// longest run covered -- which is what puts the flag on one car and a
    /// retirement on the other.
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

    /// The flag is moved later, which leaves `seq` saying what it said before
    /// -- the order the rows are in and not the one they are read in.
    @Test
    def aCorrectedRowComesBackAtItsNewMoment(): Unit \ {Assert, IO} =
        let events = TestSupport.onRound(entry(),
            lap("7", 1, "60.000") ::
            lap("7", 2, "3:00.000") ::
            Nil,
            () -> {
                Db.execute("UPDATE ${Db.TimelineEvents.table()} SET elapsed_ms = 250000"
                    + " WHERE event = 'checkered'");
                Timeline.read(entry())
            });
        Assert.assertTrue(named("checkered", events) == ("4:10.000", "checkered", "7") :: Nil);
        let times = events |> List.map(event -> event#elapsed);
        Assert.assertTrue(times == List.sort(times))

    @Test
    def theRowsReadBackAsTheTimelineTheLoadCounted(): Unit \ {Assert, IO} =
        match loadedAndCounted() {
            case (readBack, counted) =>
                Assert.assertTrue(List.map(shape, readBack) == List.map(shape, counted))
        }

    @Test
    def everyKindOfEventComesBackThroughARow(): Unit \ {Assert, IO} =
        match loadedAndCounted() {
            case (readBack, _) =>
                Assert.assertTrue(named("raceStart", readBack) == ("0.000", "raceStart", "") :: Nil);
                Assert.assertTrue(named("leaderPitted", readBack) ==
                    ("1:00:00.000", "leaderPitted", "7") :: Nil);
                Assert.assertTrue(named("tookLeadOnTrack", readBack) ==
                    ("1:30:00.000", "tookLeadOnTrack", "7") :: Nil);
                Assert.assertTrue(named("checkered", readBack) == ("1:30:00.000", "checkered", "7") :: Nil);
                Assert.assertTrue(named("retirement", readBack) == ("50:00.000", "retirement", "8") :: Nil)
        }

}
