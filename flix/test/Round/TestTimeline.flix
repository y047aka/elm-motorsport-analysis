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
    use Motorsport.Flag.Flag
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
    /// The race start and a flag are nobody's, and read back with an empty car
    /// number.
    def shape(event: Event): (String, String, String) =
        let when = Util.Duration.format(event#elapsed);
        match event#eventType {
            case EventType.RaceStart => (when, "raceStart", "")
            case EventType.Flag(flag) => (when, flagName(flag), "")
            case EventType.Of(carNumber, carEvent) => (when, name(carEvent), carNumber)
        }

    def flagName(flag: Flag): String =
        match flag {
            case Flag.FullCourseYellow => "fullCourseYellow"
            case Flag.SafetyCar        => "safetyCar"
            case Flag.RedFlag          => "redFlag"
            case Flag.GreenFlag        => "greenFlag"
        }

    def name(carEvent: CarEvent): String =
        match carEvent {
            case CarEvent.OvertakeForLead => "overtakeForLead"
            case CarEvent.LeaderInPit     => "leaderInPit"
            case CarEvent.FastestLap      => "fastestLap"
            case CarEvent.DriverChange    => "driverChange"
            case CarEvent.Retired         => "retired"
            case CarEvent.Finished        => "finished"
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
        "overtakeForLead" :: "leaderInPit" :: Nil

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

    /// A lap of an LMGT3 car, the class every other helper's car is not in.
    def gtLap(num: String, lapNumber: Int32, elapsed: String): RawLap =
        crossingOf("LMGT3;", num, "1", lapNumber, elapsed, "", "")

    def gtPitLap(num: String, lapNumber: Int32, elapsed: String, pit: String): RawLap =
        crossingOf("LMGT3;", num, "1", lapNumber, elapsed, "", pit)

    def gtBoxLap(num: String, lapNumber: Int32, elapsed: String): RawLap =
        crossingOf("LMGT3;", num, "1", lapNumber, elapsed, "B", "")

    /// A Hypercar's lap of the time given, which the other helpers fix at a minute.
    def timedLap(num: String, lapNumber: Int32, elapsed: String, lapTime: String): RawLap =
        timedCrossingOf("HYPERCAR;H", num, "1", lapNumber, elapsed, lapTime, "", "")

    def gtTimedLap(num: String, lapNumber: Int32, elapsed: String, lapTime: String): RawLap =
        timedCrossingOf("LMGT3;", num, "1", lapNumber, elapsed, lapTime, "", "")

    /// A car's out-lap under the driver the car was handed to.
    def handedPitLap(num: String, driver: String, lapNumber: Int32, elapsed: String, pit: String): RawLap =
        crossingOf("HYPERCAR;H", num, driver, lapNumber, elapsed, "", pit)

    /// A lap under a driver other than the car's first.
    def seatedLap(num: String, driver: String, lapNumber: Int32, elapsed: String): RawLap =
        crossingOf("HYPERCAR;H", num, driver, lapNumber, elapsed, "", "")

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
        crossingOf("HYPERCAR;H", num, "1", lapNumber, elapsed, box, pit)

    /// `classAndGroup` is the file's `CLASS;GROUP`, two fields in one.
    def crossingOf(
        classAndGroup: String,
        num: String,
        driver: String,
        lapNumber: Int32,
        elapsed: String,
        box: String,
        pit: String
    ): RawLap =
        timedCrossingOf(classAndGroup, num, driver, lapNumber, elapsed, "60.000", box, pit)

    def timedCrossingOf(
        classAndGroup: String,
        num: String,
        driver: String,
        lapNumber: Int32,
        elapsed: String,
        lapTime: String,
        box: String,
        pit: String
    ): RawLap =
        flaggedCrossingOf(classAndGroup, num, driver, lapNumber, elapsed, lapTime, box, pit, "GF")

    /// `flag` is the file's `FLAG_AT_FL`: `GF`, `FCY`, `SF`, `RF` or `FF`.
    def flaggedCrossingOf(
        classAndGroup: String,
        num: String,
        driver: String,
        lapNumber: Int32,
        elapsed: String,
        lapTime: String,
        box: String,
        pit: String,
        flag: String
    ): RawLap =
        decodeOne(header() + "\n"
            + "${num};${driver};${lapNumber};${lapTime};0;${box};20.000;0;20.000;0;20.000;0;100;${elapsed};11:00:00.000;"
            + "0:20.000;0:20.000;0:20.000;200;Driver;${pit};${classAndGroup};Team;Maker;${flag};20.000;20.000;20.000;")

    /// A Hypercar's lap completed under the flag given.
    def flaggedLap(num: String, lapNumber: Int32, elapsed: String, flag: String): RawLap =
        flaggedCrossingOf("HYPERCAR;H", num, "1", lapNumber, elapsed, "60.000", "", "", flag)

    /// The flags a timeline shows, in the order it shows them.
    def flagsOf(events: List[Event]): List[(String, String, String)] =
        events |> List.map(shape)
            |> List.filter(match (_, kind, _) ->
                List.memberOf(kind, "fullCourseYellow" :: "safetyCar" :: "redFlag" :: "greenFlag" :: Nil))

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
        Assert.assertTrue(named("finished", events) == ("2:01.000", "finished", "7") :: Nil);
        Assert.assertTrue(named("retired", events) == ("1:02.000", "retired", "8") :: Nil)

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
            ("2:03.000", "overtakeForLead", "8") ::
            ("3:00.000", "overtakeForLead", "7") :: Nil)

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
        Assert.assertTrue(leadChanges(events) == ("2:40.000", "leaderInPit", "7") :: Nil)

    /// A stop written over its two crossings is timed at the in-lap, where the car
    /// turned down the lane, and the change of the lead the stop settled is no event:
    /// whoever stayed out overtook no one. Taking the lead back a lap later is an overtake.
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
            ("2:01.000", "leaderInPit", "7") ::
            ("2:45.000", "overtakeForLead", "7") ::
            Nil)

    /// The case the lead says nothing about: the leader came in and came back out in
    /// front of the field, so no lap boundary changed hands and there is no overtake
    /// to hang the stop on. The event is timed at where the car turned down the lane.
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
        Assert.assertTrue(leadChanges(events) == ("3:00.000", "leaderInPit", "7") :: Nil)

    /// A leader that came back out in front and was overtaken on the lap after its
    /// out-lap lost the lead on the track: its crossing of that lap is not in the
    /// pit lane, whatever the lap before it was.
    @Test
    def aLeaderOvertakenTheLapAfterItsOutLapLostItOnTrack(): Unit \ {Assert, IO} =
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
            ("3:00.000", "leaderInPit", "7") ::
            ("5:30.000", "overtakeForLead", "8") ::
            Nil)

    /// A leader that stopped for good was overtaken by nobody: the car behind leads
    /// the next lap without an event, and the leader's own is its retirement.
    @Test
    def aLeadTheLeaderLeftByRetiringIsNoOvertake(): Unit \ {Assert, IO} =
        let events = timelineOf("3:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            lap("8", 2, "2:03.000") ::
            lap("8", 3, "3:04.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) == Nil);
        Assert.assertTrue(named("retired", events) == ("1:00.000", "retired", "7") :: Nil)

    /// A second stop straight after one is the leader's only if the car still led
    /// when it came back out of the first: this one lost the lead on its out-lap, so
    /// the stop after is nobody's event.
    @Test
    def aStopStraightAfterTheLeadWasLostIsNoEvent(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "70.000") ::
            boxLap("7", 2, "2:00.000") ::
            lap("8", 2, "2:10.000") ::
            lap("8", 3, "3:10.000") ::
            pitLap("7", 3, "3:30.000", "45.000") ::
            lap("8", 4, "4:10.000") ::
            pitLap("7", 4, "4:40.000", "40.000") ::
            lap("8", 5, "5:10.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) == ("2:00.000", "leaderInPit", "7") :: Nil)

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

    /// Each class is led on its own: a GT car overtaking for its class lead is an
    /// event however far behind the Hypercars it crosses, and the Hypercar that
    /// leads the field leads only its own class.
    @Test
    def eachClassIsLedOnItsOwn(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            gtLap("90", 1, "70.000") ::
            gtLap("91", 1, "72.000") ::
            lap("7", 2, "2:00.000") ::
            lap("8", 2, "2:03.000") ::
            gtLap("91", 2, "2:20.000") ::
            gtLap("90", 2, "2:25.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) == ("2:20.000", "overtakeForLead", "91") :: Nil)

    /// A class leader going into the pits is its class's event, though a car of
    /// another class led the field at every crossing of it.
    @Test
    def aClassLeaderInThePitsIsAnEvent(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            gtLap("90", 1, "70.000") ::
            gtLap("91", 1, "75.000") ::
            lap("7", 2, "2:00.000") ::
            gtLap("90", 2, "2:20.000") ::
            gtLap("91", 2, "2:25.000") ::
            lap("7", 3, "3:00.000") ::
            gtBoxLap("90", 3, "3:30.000") ::
            gtLap("91", 3, "3:35.000") ::
            lap("7", 4, "4:00.000") ::
            gtLap("91", 4, "4:30.000") ::
            gtPitLap("90", 4, "4:40.000", "45.000") ::
            Nil);
        Assert.assertTrue(leadChanges(events) == ("3:30.000", "leaderInPit", "90") :: Nil)

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

    // ------------------------------------------------------------------ flags

    /// A caution is the first crossing under its flag, whoever made it, and green
    /// is the first crossing under green after it.
    @Test
    def aCautionAndItsEndAreTheCrossingsTheFlagChangedAt(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            flaggedLap("7", 1, "60.000", "GF") ::
            flaggedLap("8", 1, "62.000", "GF") ::
            flaggedLap("7", 2, "2:00.000", "FCY") ::
            flaggedLap("8", 2, "2:03.000", "FCY") ::
            flaggedLap("7", 3, "3:10.000", "GF") ::
            flaggedLap("8", 3, "3:13.000", "GF") ::
            Nil);
        Assert.assertTrue(flagsOf(events) ==
            ("2:00.000", "fullCourseYellow", "") ::
            ("3:10.000", "greenFlag", "") :: Nil)

    /// A yellow the safety car takes over from is two cautions and one green: no
    /// racing ran between them.
    @Test
    def aSafetyCarAfterAYellowIsNoGreenBetweenThem(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            flaggedLap("7", 1, "60.000", "GF") ::
            flaggedLap("7", 2, "2:00.000", "FCY") ::
            flaggedLap("7", 3, "3:30.000", "SF") ::
            flaggedLap("7", 4, "5:00.000", "RF") ::
            flaggedLap("7", 5, "8:00.000", "SF") ::
            flaggedLap("7", 6, "9:30.000", "GF") ::
            Nil);
        Assert.assertTrue(flagsOf(events) ==
            ("2:00.000", "fullCourseYellow", "") ::
            ("3:30.000", "safetyCar", "") ::
            ("5:00.000", "redFlag", "") ::
            ("8:00.000", "safetyCar", "") ::
            ("9:30.000", "greenFlag", "") :: Nil)

    /// The race starts green, so a start behind the safety car is a change at the
    /// first crossing; and the finish's own flag is no change at all.
    @Test
    def aSafetyCarStartIsAChangeAndTheFinishIsNone(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            flaggedLap("7", 1, "1:30.000", "SF") ::
            flaggedLap("7", 2, "3:00.000", "GF") ::
            flaggedLap("7", 3, "4:00.000", "FF") ::
            Nil);
        Assert.assertTrue(flagsOf(events) ==
            ("1:30.000", "safetyCar", "") ::
            ("3:00.000", "greenFlag", "") :: Nil)

    // ----------------------------------------------------------- fastest laps

    /// Each class's fastest lap as it fell, and no event for a lap only as fast
    /// as the one standing: the GT's 2:10 is a record of its class though a
    /// Hypercar had run a 2:00.
    @Test
    def eachClassHasItsOwnFastestLap(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            timedLap("7", 1, "2:00.000", "2:00.000") ::
            gtTimedLap("90", 1, "2:10.000", "2:10.000") ::
            timedLap("7", 2, "4:02.000", "2:02.000") ::
            gtTimedLap("90", 2, "4:20.000", "2:10.000") ::
            timedLap("7", 3, "6:02.000", "2:00.000") ::
            gtTimedLap("90", 3, "6:28.000", "2:08.000") ::
            timedLap("7", 4, "8:02.000", "2:00.000") ::
            Nil);
        Assert.assertTrue(named("fastestLap", events) ==
            ("4:02.000", "fastestLap", "7") ::
            ("4:20.000", "fastestLap", "90") ::
            ("6:02.000", "fastestLap", "7") ::
            ("6:28.000", "fastestLap", "90") :: Nil)

    /// Lap 1 sets nothing, however fast it reads, and a lap the feed wrote no
    /// time for is not a lap of no time.
    @Test
    def neitherTheFirstLapNorAnUntimedOneIsARecord(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            timedLap("7", 1, "1:50.000", "1:50.000") ::
            timedLap("7", 2, "3:52.000", "0.000") ::
            timedLap("7", 3, "5:54.000", "2:02.000") ::
            Nil);
        Assert.assertTrue(named("fastestLap", events) == ("5:54.000", "fastestLap", "7") :: Nil)

    // -------------------------------------------------------- driver changes

    /// A car handed over at a stop is one event, timed where the driver before it
    /// turned into the pit lane; a stop that kept its driver is none.
    @Test
    def aDriverChangeIsTimedAtTheCrossingIntoThePits(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            lap("8", 1, "62.000") ::
            boxLap("7", 2, "2:00.000") ::
            boxLap("8", 2, "2:02.000") ::
            handedPitLap("7", "2", 3, "3:00.000", "40.000") ::
            pitLap("8", 3, "3:02.000", "40.000") ::
            seatedLap("7", "2", 4, "4:00.000") ::
            lap("8", 4, "4:02.000") ::
            Nil);
        Assert.assertTrue(named("driverChange", events) == ("2:00.000", "driverChange", "7") :: Nil)

    /// A driver sharing a car with another sits in it again: each hand-over is
    /// one, whichever of them it goes to.
    @Test
    def everyHandOverIsOneEvenBackToADriverBefore(): Unit \ {Assert, IO} =
        let events = timelineOf("1:00:00.000",
            lap("7", 1, "60.000") ::
            handedPitLap("7", "2", 2, "2:00.000", "30.000") ::
            handedPitLap("7", "1", 3, "3:00.000", "30.000") ::
            Nil);
        Assert.assertTrue(named("driverChange", events) ==
            ("1:00.000", "driverChange", "7") ::
            ("2:00.000", "driverChange", "7") :: Nil)

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
    /// longest run covered -- which is what puts the flag on two cars and a
    /// retirement on the third.
    def loadedAndCounted(): (List[Event], List[Event]) \ IO =
        let laps =
            lap("7", 1, "30:00.000") ::
            lap("8", 1, "31:00.000") ::
            lap("9", 1, "32:00.000") ::
            lap("8", 2, "50:00.000") ::
            pitLap("7", 2, "1:00:00.000", "1:10.000") ::
            lap("7", 3, "1:30:00.000") ::
            lap("8", 3, "1:31:00.000") ::
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
                    + " WHERE event = 'finished'");
                Timeline.read(entry())
            });
        Assert.assertTrue(named("finished", events) == ("4:10.000", "finished", "7") :: Nil);
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
                Assert.assertTrue(named("leaderInPit", readBack) ==
                    ("1:00:00.000", "leaderInPit", "7") :: Nil);
                Assert.assertTrue(named("overtakeForLead", readBack) ==
                    ("1:30:00.000", "overtakeForLead", "7") :: Nil);
                Assert.assertTrue(named("finished", readBack) ==
                    ("1:30:00.000", "finished", "7") :: ("1:31:00.000", "finished", "8") :: Nil);
                Assert.assertTrue(named("retired", readBack) == ("32:00.000", "retired", "9") :: Nil)
        }

}
