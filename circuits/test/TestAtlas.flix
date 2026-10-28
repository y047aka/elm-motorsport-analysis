/// The atlas reading's asking of its arguments: which layer a run reads and from
/// where. The measuring itself is `TestMidline`'s and the apartness `TestApart`'s; what
/// is met here is the half that opens nothing — a word no circuit answers to, a flag
/// that names no file, and the two answers one layer cannot be given twice.
pub mod TestAtlas {

    /// The default reading is offline: the circuit's own kept line, named nowhere,
    /// asked of no home.
    @Test
    def testTheDefaultReadingReadsTheKeptLine(): Unit \ Assert =
        match Atlas.parse("cota" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#circuit#word == "cota");
                Assert.assertTrue(asked#file == None);
                Assert.assertTrue(not asked#fetch)
        }

    @Test
    def testFetchAsksTheHomeAndNamedFileReadsTheKeptOne(): Unit \ Assert =
        match Atlas.parse("cota" :: "--fetch" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) => Assert.assertTrue(asked#fetch)
        };
        match Atlas.parse("cota" :: "--file" :: "elsewhere.geojson" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#file == Some("elsewhere.geojson"));
                Assert.assertTrue(not asked#fetch)
        }

    /// A flag is no file, and `--file` beside `--fetch` says to read a kept layer and
    /// that the run should read nowhere — one layer cannot be given two answers.
    @Test
    def testTheAskingRefusesWhatItCannotReadFrom(): Unit \ Assert =
        Assert.assertTrue(
            refused("--file names no file to read", Atlas.parse("cota" :: "--file" :: "--fetch" :: Nil))
        );
        Assert.assertTrue(
            refused(
                "--file and --fetch ask for opposite things",
                Atlas.parse("cota" :: "--file" :: "kept.geojson" :: "--fetch" :: Nil)
            )
        );
        Assert.assertTrue(refused("atlas reads one circuit", Atlas.parse(Nil)))

    def refused(problem: String, asked: Result[Cli.Args.ArgsError, Atlas.Request]): Bool =
        match asked {
            case Err(one) => String.contains({substr = problem}, "${one}")
            case Ok(_)    => false
        }
}
