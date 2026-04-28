mod TestFileTask {

    @Test
    def testMakeWithOutputOverride(): Unit \ Assert =
        let task = FileTask.make("input.csv", Some("custom.json"));
        Assert.assertTrue(task#inputPath == "input.csv");
        Assert.assertTrue(task#outputPath == "custom.json");
        Assert.assertTrue(task#lapsPath == "custom_laps.json");
        Assert.assertTrue(task#eventName == "input")

    @Test
    def testMakeWithoutOutputOverride(): Unit \ Assert =
        let task = FileTask.make("input.csv", None);
        Assert.assertTrue(task#inputPath == "input.csv");
        Assert.assertTrue(task#outputPath == "input.json");
        Assert.assertTrue(task#lapsPath == "input_laps.json");
        Assert.assertTrue(task#eventName == "input")

    @Test
    def testMakeDefaultOutputPathCsv(): Unit \ Assert =
        let task = FileTask.make("data/race.csv", None);
        Assert.assertTrue(task#outputPath == "data/race.json");
        Assert.assertTrue(task#lapsPath == "data/race_laps.json")

    @Test
    def testMakeDefaultOutputPathNonCsv(): Unit \ Assert =
        let task = FileTask.make("data/race.txt", None);
        Assert.assertTrue(task#outputPath == "data/race.txt.json");
        Assert.assertTrue(task#lapsPath == "data/race.txt_laps.json")

    @Test
    def testEventNameSimple(): Unit \ Assert =
        let task = FileTask.make("race.csv", None);
        Assert.assertTrue(task#eventName == "race")

    @Test
    def testEventNameWithPath(): Unit \ Assert =
        let task = FileTask.make("data/wec/2025/race.csv", None);
        Assert.assertTrue(task#eventName == "race")

    @Test
    def testEventNameNoExtension(): Unit \ Assert =
        let task = FileTask.make("data/race", None);
        Assert.assertTrue(task#eventName == "race")

    @Test
    def testLapsPathFromOverrideWithExtension(): Unit \ Assert =
        let task = FileTask.make("input.csv", Some("data/out.bin"));
        Assert.assertTrue(task#outputPath == "data/out.bin");
        Assert.assertTrue(task#lapsPath == "data/out_laps.json")

    @Test
    def testLapsPathFromOverrideWithoutExtension(): Unit \ Assert =
        let task = FileTask.make("input.csv", Some("output"));
        Assert.assertTrue(task#outputPath == "output");
        Assert.assertTrue(task#lapsPath == "output_laps.json")

    @Test
    def testLapsPathFromDirectoryPath(): Unit \ Assert =
        let task = FileTask.make("input.csv", Some("/tmp/runs/foo.json"));
        Assert.assertTrue(task#outputPath == "/tmp/runs/foo.json");
        Assert.assertTrue(task#lapsPath == "/tmp/runs/foo_laps.json")

}
