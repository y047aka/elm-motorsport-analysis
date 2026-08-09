mod Cli.Stages.TestUnlisted {

    use Cli.FileTask
    use Cli.Stages.Unlisted

    def tasks(root: String): List[FileTask.FileTask] = FileTask.fromCalendar(root)

    /// A CSV every run is expected to find, spelled the way the walk returns it.
    def listedCsv(): String = "../app/static/wec/2025/spa_6h.csv"

    @Test
    def testACsvOnTheCalendarIsNotReported(): Unit \ Assert =
        let found = listedCsv() :: "../app/static/wec/2026/imola_6h.csv" :: Nil;
        Assert.assertTrue(Unlisted.detect(tasks("../app/static/wec"), found) == Nil)

    @Test
    def testACsvNoRoundNamesIsReported(): Unit \ Assert =
        let stray = "../app/static/wec/2025/monza_6h.csv";
        let found = listedCsv() :: stray :: Nil;
        Assert.assertTrue(Unlisted.detect(tasks("../app/static/wec"), found) == stray :: Nil)

    /// 2024 ran no round at Imola, so a file that looks right in every way but
    /// the year it is filed under is still not on the calendar.
    @Test
    def testARoundFiledUnderTheWrongSeasonIsReported(): Unit \ Assert =
        let found = "../app/static/wec/2024/imola_6h.csv" :: Nil;
        Assert.assertTrue(List.length(Unlisted.detect(tasks("../app/static/wec"), found)) == 1)

    /// The half that used to be wrong. Both sides name the same file; only the
    /// spelling of the root differs, and a run that reported all fourteen would
    /// make the warning worthless.
    @Test
    def testTheSpellingOfTheRootDoesNotMatter(): Unit \ Assert =
        let found = listedCsv() :: Nil;
        Assert.assertTrue(Unlisted.detect(tasks("../app/static/wec/"), found) == Nil);
        Assert.assertTrue(Unlisted.detect(tasks("../app/static/./wec"), found) == Nil);
        Assert.assertTrue(Unlisted.detect(tasks("/srv/app/static/wec"), found) == Nil)

    /// Nothing is filed directly under the root or below a season directory, so
    /// neither can match a round.
    @Test
    def testAFileOutsideASeasonDirectoryIsReported(): Unit \ Assert =
        let found = "../app/static/wec/spa_6h.csv" :: "../app/static/wec/2025/old/spa_6h.csv" :: Nil;
        Assert.assertTrue(List.length(Unlisted.detect(tasks("../app/static/wec"), found)) == 2)

    @Test
    def testTheReportedPathIsTheOneThatWasFound(): Unit \ Assert =
        let stray = "/srv/app/static/wec/2025/monza_6h.csv";
        Assert.assertTrue(Unlisted.detect(tasks("../app/static/wec"), stray :: Nil) == stray :: Nil)

    @Test
    def testRoundKeyIsTheSeasonDirectoryAndTheFile(): Unit \ Assert =
        Assert.assertTrue(Unlisted.roundKey("../app/static/wec/2025/spa_6h.csv") == ("2025", "spa_6h.csv"));
        Assert.assertTrue(Unlisted.roundKey("/2025//spa_6h.csv") == ("2025", "spa_6h.csv"));
        Assert.assertTrue(Unlisted.roundKey("spa_6h.csv") == ("", "spa_6h.csv"))

}
