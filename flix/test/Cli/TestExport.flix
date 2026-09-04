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
        { inputPath = "", outputPath = "", lapsPath = "", entry = entry }

    def readBack(loaded: Entry, wanted: Entry): Result[CliError, Rendered] \ IO =
        TestSupport.onRound(loaded, TestLapRow.sampleLaps(), () -> Ok(Export.read(task(wanted))))

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
                let lines = String.splitOn({substr = "\n"}, rendered#lapsJsonl)
                    |> List.filter(line -> line != "");
                Assert.assertTrue(List.length(lines) == 3)
            case Err(_) => Assert.assertTrue(false)
        }

}
