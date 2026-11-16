pub mod Db.TestTimelineEvents {

    use Db.Schema
    use Db.TimelineEvents
    use Db.TimelineEvents.EventRow
    use Motorsport.Timeline
    use Motorsport.Timeline.CarEvent
    use Motorsport.Timeline.Event
    use Motorsport.Timeline.EventType
    use Motorsport.Flag.Flag
    use Util.Json.Extra

    def at(ms: Int32, eventType: EventType): Event =
        { elapsed = Util.Duration.fromMillis(ms), eventType = eventType, lap = None }

    /// One of each, which is what the row has to carry between them.
    def oneOfEach(): List[Event] =
        at(0, EventType.RaceStart) ::
        at(600, EventType.Flag(Flag.FullCourseYellow)) ::
        at(800, EventType.Flag(Flag.SafetyCar)) ::
        at(850, EventType.Flag(Flag.RedFlag)) ::
        at(900, EventType.Flag(Flag.GreenFlag)) ::
        at(1000, EventType.Of("7", CarEvent.OvertakeForLead)) ::
        at(1200, EventType.Of("8", CarEvent.LeaderInPit)) ::
        at(1200, EventType.Of("8", CarEvent.FastestLap)) ::
        at(1200, EventType.Of("8", CarEvent.DriverChange)) ::
        at(4000, EventType.Of("8", CarEvent.Retired)) ::
        at(5000, EventType.Of("7", CarEvent.Finished)) ::
        Nil

    def line(event: Event): String =
        Extra.renderOnOneLine(Timeline.toJson(event))

    // ------------------------------------------------------------ the rows

    @Test
    def theEventsAreNumberedFromNoughtInOrder(): Unit \ Assert =
        let rows = TimelineEvents.fromEvents(3, oneOfEach());
        Assert.assertTrue(rows |> List.map(r -> r#seq) == List.range(0, 11));
        Assert.assertTrue(rows |> List.forAll(r -> r#roundId == 3))

    /// Compared as the line the event is written out as, which is the other
    /// writing of the same parts.
    @Test
    def aRowReadsBackAsTheEventItWasMadeFrom(): Unit \ Assert =
        let readBack = TimelineEvents.fromEvents(1, oneOfEach())
            |> List.map(TimelineEvents.toEvent)
            |> List.sequence;
        match readBack {
            case Some(events) =>
                Assert.assertTrue(List.map(line, events) == List.map(line, oneOfEach()))
            case None => Assert.assertTrue(false)
        }

    @Test
    def onlyTheRaceStartAndTheFlagsCarryNoCar(): Unit \ Assert =
        let rows = TimelineEvents.fromEvents(1, oneOfEach());
        Assert.assertTrue(rows |> List.filter(r -> Option.isEmpty(r#carNumber))
            |> List.map(r -> r#event) ==
                "raceStart" :: "fullCourseYellow" :: "safetyCar" :: "redFlag" :: "greenFlag" :: Nil)

    /// What a row would read as had it got past the column's check, which is
    /// `Motorsport.Timeline.names`.
    @Test
    def aNameNoEventAnswersToSpellsNone(): Unit \ Assert =
        let row = {
            roundId = 1, seq = 0, elapsedMs = 0, event = "slowZone",
            carNumber = Some("7"), lapNumber = None
        };
        Assert.assertTrue(Option.isEmpty(TimelineEvents.toEvent(row)));
        Assert.assertTrue(not List.memberOf("slowZone", Timeline.names()))

    /// The lap an event fell on, written into the row by `parts` and read back
    /// by `toEvent`, and out again as the line the event is written as.
    @Test
    def theLapAnEventFellOnSurvivesTheRow(): Unit \ Assert =
        let event = {
            elapsed = Util.Duration.fromMillis(1200),
            eventType = EventType.Of("8", CarEvent.FastestLap),
            lap = Some(37)
        };
        let rows = TimelineEvents.fromEvents(1, event :: Nil);
        Assert.assertTrue(List.map(r -> r#lapNumber, rows) == Some(37) :: Nil);
        Assert.assertTrue(line(event) ==
            "{ \"elapsed\": \"1.200\", \"event\": \"fastestLap\", \"carNumber\": \"8\", \"lap\": 37 }");
        match List.head(rows) |> Option.flatMap(TimelineEvents.toEvent) {
            case Some(readBack) =>
                Assert.assertTrue(readBack#lap == Some(37));
                Assert.assertTrue(Util.Duration.format(readBack#elapsed) == "1.200")
            case None => Assert.assertTrue(false)
        }

    /// An event that fell on no lap is written with no `lap` at all.
    @Test
    def anEventOnNoLapCarriesNoLap(): Unit \ Assert =
        Assert.assertTrue(line(at(600, EventType.Flag(Flag.FullCourseYellow))) ==
            "{ \"elapsed\": \"0.600\", \"event\": \"fullCourseYellow\" }");
        Assert.assertTrue(List.forAll(r -> Option.isEmpty(r#lapNumber),
            TimelineEvents.fromEvents(1, oneOfEach())))

    // --------------------------------------------------------------- schema

    @Test
    def theCheckAllowsExactlyTheNamesTheEventsGoBy(): Unit \ Assert =
        let written = TimelineEvents.fromEvents(1, oneOfEach()) |> List.map(r -> r#event);
        Assert.assertTrue(List.sort(written) == List.sort(Timeline.names()))

    @Test
    def theKeyIsOverColumnsTheTableDeclares(): Unit \ Assert =
        Assert.assertTrue(
            TimelineEvents.primaryKey()
                |> List.forAll(c -> List.memberOf(c#name, TimelineEvents.columnNames()))
        )

}
