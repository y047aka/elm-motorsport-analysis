mod Cli.TestExport {

    use Db.TestLapRow
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Export
    use Cli.Export.Rendered
    use Round.TestSupport
    use Motorsport.Calendar.Entry

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }

    def imola(): Entry = { season = 2025, id = "imola_6h", date = "2025-04-20" }

    /// The paths are never reached: `read` decides before anything is written.
    def task(entry: Entry): FileTask.FileTask =
        { inputPath = "", outputPath = "", lapsPath = "", timelinePath = "", entry = entry }

    def readBack(loaded: Entry, wanted: Entry): Result[CliError, Rendered] \ IO =
        TestSupport.onRound(loaded, TestLapRow.sampleLaps(), () -> Export.read(task(wanted)))

    def lines(jsonl: String): List[String] =
        String.splitOn({substr = "\n"}, jsonl) |> List.filter(line -> line != "")

    @Test
    def aRoundNoRunHasLoadedIsNotWrittenOut(): Unit \ {Assert, IO} =
        match readBack(fuji(), imola()) {
            case Err(CliError.RoundNotLoaded) => Assert.assertTrue(true)
            case _                            => Assert.assertTrue(false)
        }

    /// The count is of what was written, which is what the run reports; the two
    /// bodies are what `Round.Render` was asked for.
    @Test
    def aLoadedRoundIsWrittenOut(): Unit \ {Assert, IO} =
        match readBack(fuji(), fuji()) {
            case Ok(rendered) =>
                Assert.assertTrue(rendered#lapCount == 3);
                Assert.assertTrue(String.contains({substr = "\"6 Hours of Fuji\""}, rendered#metadataJson));
                Assert.assertTrue(List.length(lines(rendered#lapsJsonl)) == 3);
                // The start, two cars taking it, two flags, car 12's stop on
                // lap 2, and the lead it took coming out of it.
                Assert.assertTrue(List.length(lines(rendered#timelineJsonl)) == 8)
            case Err(_) => Assert.assertTrue(false)
        }

}
