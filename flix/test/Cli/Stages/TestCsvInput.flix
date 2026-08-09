mod Cli.Stages.TestCsvInput {

    use Cli.Errors.CliError
    use Cli.Stages.CsvInput

    /// The other half of the calendar's two-way check: a round is listed and
    /// its CSV was never filed.
    @Test
    def testAListedRoundWithNoCsvFailsAsMissing(): Unit \ {Assert, IO} =
        match CsvInput.read("../app/static/wec/2025/monza_6h.csv") {
            case Err(CliError.InputPathNotFound(p)) => Assert.assertTrue(p == "../app/static/wec/2025/monza_6h.csv")
            case _                                  => Assert.assertTrue(false)
        }

    @Test
    def testACsvThatIsThereIsRead(): Unit \ {Assert, IO} =
        match CsvInput.read("../app/static/wec/2025/spa_6h.csv") {
            case Ok(content) => Assert.assertTrue(String.startsWith({prefix = "NUMBER;"}, content))
            case Err(_)      => Assert.assertTrue(false)
        }

}
