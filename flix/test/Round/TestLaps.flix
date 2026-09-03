mod Round.TestLaps {

    use Db.TestLapRow
    use Round.Laps
    use Round.TestRound
    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Util.Json.Encode.Extra

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }

    def readBack(laps: List[RawLap]): List[RawLap] \ IO =
        TestRound.onRound(fuji(), laps, () -> Laps.read(fuji()))

    def rendered(laps: List[RawLap]): List[String] =
        laps |> List.map(lap -> Extra.renderOnOneLine(Wec.toJson(lap)))

    @Test
    def aRoundReadsBackAsTheLapsItWasLoadedFrom(): Unit \ {Assert, IO} =
        let laps = TestLapRow.sampleLaps();
        Assert.assertTrue(rendered(readBack(laps)) == rendered(laps))

    /// The file's order, which is neither the lap number's nor the car
    /// number's.
    @Test
    def theLapsComeBackInTheOrderTheFileListedThem(): Unit \ {Assert, IO} =
        let listed = lap -> (lap#car#carNumber, lap#lapNumber);
        Assert.assertTrue(
            List.map(listed, readBack(TestLapRow.sampleLaps()))
                == ("12", 1) :: ("12", 2) :: ("7", 1) :: Nil
        )

    @Test
    def aRoundWithNoRowsReadsAsNoLaps(): Unit \ {Assert, IO} =
        Assert.assertTrue(List.isEmpty(readBack(Nil)))

}
