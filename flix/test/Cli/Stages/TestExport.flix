mod Cli.Stages.TestExport {

    use Db.TestLapRow
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Stages.Export
    use Cli.Stages.Transform.Rendered
    use Cli.TestRound
    use Motorsport.Calendar.Entry

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }

    def imola(): Entry = { season = 2025, id = "imola_6h", date = "2025-04-20" }

    /// The paths are never reached: `read` decides before anything is written.
    def task(entry: Entry): FileTask.FileTask =
        { inputPath = "", outputPath = "", lapsPath = "", entry = entry }

    def readBack(loaded: Entry, wanted: Entry): Result[CliError, Rendered] \ IO =
        TestRound.onRound(loaded, TestLapRow.sampleLaps(), () -> Ok(Export.read(task(wanted))))

    @Test
    def aRoundNoRunHasLoadedIsNotWrittenOut(): Unit \ {Assert, IO} =
        match readBack(fuji(), imola()) {
            case Err(CliError.RoundNotLoaded) => Assert.assertTrue(true)
            case _                            => Assert.assertTrue(false)
        }

    @Test
    def aLoadedRoundIsWrittenOut(): Unit \ {Assert, IO} =
        match readBack(fuji(), fuji()) {
            case Ok(rendered) => Assert.assertTrue(rendered#lapCount == 3)
            case Err(_)       => Assert.assertTrue(false)
        }

}
