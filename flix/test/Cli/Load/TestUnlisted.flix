pub mod Cli.Load.TestUnlisted {

    use Cli.FileTask
    use Cli.Load.Unlisted

    def tasks(root: String): List[FileTask.Input] = FileTask.inputs(root)

    /// A CSV every run is expected to find, spelled the way the walk returns it.
    def listedCsv(): String = "../data/wec/2025/spa_6h.csv"

    @Test
    def testACsvOnTheCalendarIsNotReported(): Unit \ Assert =
        let found = listedCsv() :: "../data/wec/2026/imola_6h.csv" :: Nil;
        Assert.assertTrue(Unlisted.detect(tasks("../data/wec"), found) == Nil)

    @Test
    def testACsvNoRoundNamesIsReported(): Unit \ Assert =
        let stray = "../data/wec/2025/monza_6h.csv";
        let found = listedCsv() :: stray :: Nil;
        Assert.assertTrue(Unlisted.detect(tasks("../data/wec"), found) == stray :: Nil)

    /// 2024 ran no round at Imola, so a file that looks right in every way but
    /// the year it is filed under is still not on the calendar.
    @Test
    def testARoundFiledUnderTheWrongSeasonIsReported(): Unit \ Assert =
        let found = "../data/wec/2024/imola_6h.csv" :: Nil;
        Assert.assertTrue(List.length(Unlisted.detect(tasks("../data/wec"), found)) == 1)

    /// Both sides name the same file and only the root is spelled differently.
    @Test
    def testTheSpellingOfTheRootDoesNotMatter(): Unit \ Assert =
        let found = listedCsv() :: Nil;
        Assert.assertTrue(Unlisted.detect(tasks("../data/wec/"), found) == Nil);
        Assert.assertTrue(Unlisted.detect(tasks("../data/./wec"), found) == Nil);
        Assert.assertTrue(Unlisted.detect(tasks("/srv/data/wec"), found) == Nil)

    @Test
    def testAFileOutsideASeasonDirectoryIsReported(): Unit \ Assert =
        let found = "../data/wec/spa_6h.csv" :: "../data/wec/2025/old/spa_6h.csv" :: Nil;
        Assert.assertTrue(List.length(Unlisted.detect(tasks("../data/wec"), found)) == 2)

}
