mod Cli.TestFileTask {

    use Cli.FileTask
    use Cli.FileTask.Rounds

    def taskFor(season: Int32, id: String): Option[FileTask.FileTask] =
        FileTask.fromCalendar("../app/static/wec")
            |> List.find(t -> t#entry#season == season and t#entry#id == id)

    @Test
    def testEveryPathHangsOffTheRootAndTheCalendarEntry(): Unit \ Assert =
        match taskFor(2025, "fuji_6h") {
            case None => Assert.assertTrue(false)
            case Some(task) =>
                Assert.assertTrue(task#inputPath  == "../app/static/wec/2025/fuji_6h.csv");
                Assert.assertTrue(task#outputPath == "../app/static/wec/2025/fuji_6h.json");
                Assert.assertTrue(task#lapsPath   == "../app/static/wec/2025/fuji_6h_laps.jsonl");
                Assert.assertTrue(task#entry#date == "2025-09-28")
        }

    /// The same round in two seasons is two tasks writing to two places, which
    /// is the whole reason the season cannot be left to the id.
    @Test
    def testTheSameRoundInTwoSeasonsIsTwoTasks(): Unit \ Assert =
        match (taskFor(2025, "spa_6h"), taskFor(2026, "spa_6h")) {
            case (Some(a), Some(b)) =>
                Assert.assertTrue(a#outputPath == "../app/static/wec/2025/spa_6h.json");
                Assert.assertTrue(b#outputPath == "../app/static/wec/2026/spa_6h.json")
            case _ => Assert.assertTrue(false)
        }

    def labelsOf(rounds: Rounds): List[String] =
        FileTask.selected("../app/static/wec", rounds) |> List.map(FileTask.label)

    /// Every season, not only the one the calendar lists first.
    @Test
    def testEveryIsEverySeason(): Unit \ Assert =
        let labels = labelsOf(Rounds.Every);
        Assert.assertTrue(List.memberOf("2026/imola_6h", labels));
        Assert.assertTrue(List.memberOf("2025/qatar_1812km", labels));
        Assert.assertTrue(List.memberOf("2024/bahrain_8h", labels))

    /// Named in one order and returned in the calendar's, so a run reports
    /// what it wrote season by season rather than as it was asked.
    @Test
    def testOnlyIsTheNamedRoundsInTheCalendarsOrder(): Unit \ Assert =
        Assert.assertTrue(
            labelsOf(Rounds.Only((2024, "fuji_6h") :: (2025, "le_mans_24h") :: Nil))
                == "2025/le_mans_24h" :: "2024/fuji_6h" :: Nil
        )

    @Test
    def testTheLabelNamesTheRoundNotJustTheFile(): Unit \ Assert =
        match taskFor(2026, "le_mans_24h") {
            case None       => Assert.assertTrue(false)
            case Some(task) => Assert.assertTrue(FileTask.label(task) == "2026/le_mans_24h")
        }

}
