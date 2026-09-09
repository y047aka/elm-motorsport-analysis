mod Db.TestTimelineEvents {

    use Db.Schema
    use Db.TimelineEvents
    use Db.TimelineEvents.EventRow
    use Motorsport.Timeline
    use Motorsport.Timeline.CarEvent
    use Motorsport.Timeline.Event
    use Motorsport.Timeline.EventType
    use Util.Duration.Duration
    use Util.Json.Encode.Extra

    def at(ms: Int32, eventType: EventType): Event =
        { elapsed = Util.Duration.fromMillis(ms), eventType = eventType }

    def length(): Duration = Util.Duration.fromMillis(70000)

    /// One of each, which is what the row has to carry between them.
    def oneOfEach(): List[Event] =
        at(0, EventType.RaceStart) ::
        at(0, EventType.Of("7", CarEvent.Start)) ::
        at(1000, EventType.Of("7", CarEvent.TookLead)) ::
        at(2000, EventType.Of("7", CarEvent.PitIn(4, length()))) ::
        at(3000, EventType.Of("7", CarEvent.PitOut(4, length()))) ::
        at(4000, EventType.Of("8", CarEvent.Retirement)) ::
        at(5000, EventType.Of("7", CarEvent.Checkered)) ::
        Nil

    def line(event: Event): String =
        Extra.renderOnOneLine(Timeline.toJson(event))

    // ------------------------------------------------------------ the rows

    /// The place an event holds in the timeline is the row's, since nothing
    /// else in it orders two events sharing an instant.
    @Test
    def theEventsAreNumberedFromNoughtInOrder(): Unit \ Assert =
        let rows = TimelineEvents.fromEvents(3, oneOfEach());
        Assert.assertTrue(rows |> List.map(r -> r#seq) == List.range(0, 7));
        Assert.assertTrue(rows |> List.forAll(r -> r#roundId == 3))

    /// A row is the event and nothing else, so reading one back is the event
    /// that was written -- compared as the line it is written out as, which is
    /// the other writing of the same parts.
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

    /// The race's own start is nobody's and every other event is somebody's,
    /// which is what the nullable car number is for.
    @Test
    def onlyTheRaceStartCarriesNoCar(): Unit \ Assert =
        let rows = TimelineEvents.fromEvents(1, oneOfEach());
        Assert.assertTrue(rows |> List.filter(r -> Option.isEmpty(r#carNumber))
            |> List.map(r -> r#event) == "raceStart" :: Nil)

    /// Only a stop has a lap and a length, and it keeps both.
    @Test
    def onlyAStopCarriesALapAndALength(): Unit \ Assert =
        let stops = TimelineEvents.fromEvents(1, oneOfEach())
            |> List.filter(r -> not Option.isEmpty(r#lapNumber))
            |> List.map(r -> (r#event, r#lapNumber, r#durationMs));
        Assert.assertTrue(stops ==
            ("pitIn", Some(4), Some(70000)) ::
            ("pitOut", Some(4), Some(70000)) :: Nil)

    /// A row carrying neither the lap a stop ended on nor its length spells no
    /// stop, and is not read back as one with either made up.
    @Test
    def aStopWithNoLapSpellsNoEvent(): Unit \ Assert =
        let row = {
            roundId = 1, seq = 0, elapsedMs = 0, event = "pitIn",
            carNumber = Some("7"), lapNumber = None, durationMs = None
        };
        Assert.assertTrue(Option.isEmpty(TimelineEvents.toEvent(row)))

    /// A name no event answers to is the same: the check the column carries is
    /// `Motorsport.Timeline.names`, and this is what a row past it reads as.
    @Test
    def aNameNoEventAnswersToSpellsNone(): Unit \ Assert =
        let row = {
            roundId = 1, seq = 0, elapsedMs = 0, event = "safetyCar",
            carNumber = Some("7"), lapNumber = None, durationMs = None
        };
        Assert.assertTrue(Option.isEmpty(TimelineEvents.toEvent(row)));
        Assert.assertTrue(not List.memberOf("safetyCar", Timeline.names()))

    // --------------------------------------------------------------- schema

    /// Every name the check allows is one the writing side can produce, and
    /// every event the writing side produces is one the check allows.
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
