mod Round.TestLaps {

    use Db.TestLapRow
    use Round.Laps
    use Round.TestSupport
    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Util.Json.Encode.Extra

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }

    def readBack(laps: List[RawLap]): List[Laps.Placed] \ IO =
        TestSupport.onRound(fuji(), laps, () -> Laps.read(fuji(), Round.Drivers.read(fuji())))

    def rendered(laps: List[RawLap]): List[String] =
        laps |> List.map(lap -> Extra.renderOnOneLine(Wec.toJson(lap)))

    @Test
    def aRoundReadsBackAsTheLapsItWasLoadedFrom(): Unit \ {Assert, IO} =
        let laps = TestLapRow.sampleLaps();
        Assert.assertTrue(rendered(readBack(laps) |> List.map(p -> p#lap)) == rendered(laps))

    /// The file's order, which is neither the lap number's nor the car
    /// number's.
    @Test
    def theLapsComeBackInTheOrderTheFileListedThem(): Unit \ {Assert, IO} =
        let listed = p -> (p#lap#car#carNumber, p#lap#lapNumber);
        Assert.assertTrue(
            List.map(listed, readBack(TestLapRow.sampleLaps()))
                == ("12", 1) :: ("12", 2) :: ("7", 1) :: Nil
        )

    /// The field at a lap, counted from nought over the cars that reached it:
    /// car 7 is round the fuji sample's first lap before car 12, and car 12
    /// has the second lap to itself.
    @Test
    def aLapCarriesWhereTheCarStoodInTheField(): Unit \ {Assert, IO} =
        let placed = readBack(TestLapRow.sampleLaps())
            |> List.map(p -> (p#lap#car#carNumber, p#lap#lapNumber, p#position));
        Assert.assertTrue(placed == ("12", 1, 1) :: ("12", 2, 0) :: ("7", 1, 0) :: Nil)

    @Test
    def aRoundWithNoRowsReadsAsNoLaps(): Unit \ {Assert, IO} =
        Assert.assertTrue(List.isEmpty(readBack(Nil)))

}
