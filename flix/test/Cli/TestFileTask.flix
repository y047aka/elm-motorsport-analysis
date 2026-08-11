mod Cli.TestFileTask {

    use Cli.FileTask

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

    @Test
    def testTheLabelNamesTheRoundNotJustTheFile(): Unit \ Assert =
        match taskFor(2026, "le_mans_24h") {
            case None       => Assert.assertTrue(false)
            case Some(task) => Assert.assertTrue(FileTask.label(task) == "2026/le_mans_24h")
        }

}
