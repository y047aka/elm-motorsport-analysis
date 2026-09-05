mod Motorsport.TestIndex {

    use Motorsport.Index
    use Motorsport.Index.Change
    use Motorsport.Index.Record
    use Motorsport.MiniSector
    use Motorsport.Sector
    use Motorsport.Sector.Sector
    use Util.Json.Encode.Extra

    def change(): Change =
        {
            elapsed   = Util.Duration.fromMillis(3723009),
            time      = Util.Duration.fromMillis(204123),
            carNumber = "7",
            lap       = 12,
            driver    = "Kamui KOBAYASHI"
        }

    def sample(): Index.Index =
        {
            lapCompletions = (1, Util.Duration.fromMillis(223009)) :: Nil,
            bestTimes      = (Record.FastestSector(Sector.S2), change() :: Nil) :: Nil
        }

    /// Every record is enumerated in one place and written from that
    /// enumeration, so one read back out of the rows cannot go missing from
    /// what is written.
    @Test
    def everyRecordIsWritten(): Unit \ Assert =
        let json = Extra.render(Index.toJson(sample()));
        Assert.assertTrue(String.contains({substr = "\"fastestLapTime\""}, json));
        Assert.assertTrue(String.contains({substr = "\"slowestLapTime\""}, json));
        Assert.assertTrue(Sector.all() |> List.forAll(s ->
            String.contains({substr = "\"${Sector.jsonKey(s)}\""}, json)));
        Assert.assertTrue(MiniSector.all() |> List.forAll(m ->
            String.contains({substr = "\"${MiniSector.jsonKey(m)}\""}, json)))

    @Test
    def theCountAgreesWithTheEnumeration(): Unit \ Assert =
        Assert.assertTrue(List.length(Index.records()) == 20)

    /// A change carries the record itself, not the time of the lap that set
    /// it, and the moment it was set at.
    @Test
    def aChangeCarriesTheRecordAndWhoTookIt(): Unit \ Assert =
        let json = Extra.render(Index.toJson(sample()));
        Assert.assertTrue(String.contains({substr = "\"elapsed\": \"1:02:03.009\""}, json));
        Assert.assertTrue(String.contains({substr = "\"time\": \"3:24.123\""}, json));
        Assert.assertTrue(String.contains({substr = "\"carNumber\": \"7\""}, json));
        Assert.assertTrue(String.contains({substr = "\"lap\": 12"}, json));
        Assert.assertTrue(String.contains({substr = "\"driver\": \"Kamui KOBAYASHI\""}, json))

    /// A lap completion is when the counter went up and to what, and fits on
    /// one line.
    @Test
    def aCompletionIsALapAndAMoment(): Unit \ Assert =
        Assert.assertTrue(String.contains(
            {substr = "{ \"lap\": 1, \"elapsed\": \"3:43.009\" }"},
            Extra.render(Index.toJson(sample()))
        ))

    /// A record nothing was read for is written as an empty list rather than
    /// left out, so a reader takes the same shape from every round.
    @Test
    def aRecordNoLapTookIsEmptyRatherThanMissing(): Unit \ Assert =
        let json = Extra.render(Index.toJson(Index.empty()));
        Assert.assertTrue(String.contains({substr = "\"lapCompletions\": []"}, json));
        Assert.assertTrue(String.contains({substr = "\"fastestLapTime\": []"}, json))

}
