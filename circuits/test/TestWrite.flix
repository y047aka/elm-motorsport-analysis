/// The geometry file as bytes: the spelling a number is given, the claims a circuit does not
/// make left unwritten, the layout every reader of a kept file reads, and where two files part.
/// `nix run .#geometry-survey` answers whether these are the bytes the app serves, and
/// `app/tests/circuits-geometry-reading.spec.ts` holds this writer and the pipeline's to one
/// claim order.
pub mod TestWrite {

    use Circuit.Circuit
    use Geometry.Place

    // ------------------------------------------------------------------ the fixtures

    /// A line of three places, at the metres a survey stretched to the published lap ends
    /// them at: the first at the line the lap is timed from, the last at the circuit's own
    /// length. Nothing is asked of the sphere here, since these are the metres the file
    /// carries rather than metres measured here again.
    def lap(): List[Survey.MetredPlace] =
        {lat = 30.1394338, lon = -97.6434495, metres = 0.0} :: {
            lat = 30.1335278,
            lon = -97.6422583,
            metres = 27.8
        } :: {lat = 30.1, lon = -97.6, metres = 5515.0} :: Nil

    /// The pit lane, which carries no metres because nothing times along it.
    def pit(): List[Place] =
        {lat = 30.13, lon = -97.638} :: {lat = 30.13, lon = -97.637} :: Nil

    def frame(): Survey.Frame = {
        origin = {lat = 30.1394338, lon = -97.6434495},
        parallel = 30.135089049999973
    }

    /// A geometry as the survey hands one over: stamped, measured and counted.
    def drawn(): Survey.Geometry = {
        centreline = lap(),
        pitLane = pit(),
        frame = frame(),
        direction = Survey.counterClockwise(),
        surveyedAt = Some("2026-10-20T07:01:01Z"),
        surveyedLength = Some(5502.238574528194),
        counts = Some({kept = 3, lap = 9, pit = 2, of = 4})
    }

    /// The same line from an answer that said nothing about itself.
    def unstamped(): Survey.Geometry = {
        centreline = lap(),
        pitLane = pit(),
        frame = frame(),
        direction = Survey.clockwise(),
        surveyedAt = None,
        surveyedLength = None,
        counts = None
    }

    /// The file a circuit's survey would write, or the sentence that refused to write one.
    def written(word: String, geometry: Survey.Geometry): Result[String, String] =
        match Circuit.byWord(word) {
            case None       => Err("the test names no circuit")
            case Some(circuit) => Ok(Write.geoJson(circuit, geometry))
        }

    def says(phrase: String, text: Result[String, String]): Unit \ Assert =
        match text {
            case Ok(file) => Assert.assertTrue(String.contains({substr = phrase}, file))
            case Err(problem) => Assert.assertTrueWithMsg(false, "the writer refused: ${problem}")
        }

    def saysNot(phrase: String, text: Result[String, String]): Unit \ Assert =
        match text {
            case Ok(file) => Assert.assertTrue(not String.contains({substr = phrase}, file))
            case Err(problem) => Assert.assertTrueWithMsg(false, "the writer refused: ${problem}")
        }

    // ------------------------------------------------------------------- the numbers

    @Test
    def testANumberIsSpelledAsJsonSpellsIt(): Unit \ Assert =
        // A whole number carries no decimal point, a double carries every digit that reads
        // back as the same number, and a negative longitude keeps its sign.
        Assert.assertTrue(Write.number(5515.0) == "5515");
        Assert.assertTrue(Write.number(0.0) == "0");
        Assert.assertTrue(Write.number(1313.2) == "1313.2");
        Assert.assertTrue(Write.number(-97.6) == "-97.6");
        Assert.assertTrue(Write.number(30.135089049999973) == "30.135089049999973")

    @Test
    def testAWordIsQuotedAndEscaped(): Unit \ Assert =
        // A sector map's name carries an apostrophe, which JSON carries as itself; a quote,
        // a backslash and a newline are the three a word cannot hold unescaped.
        Assert.assertTrue(Write.text("the circuit's own track sector map") == "\"the circuit's own track sector map\"");
        Assert.assertTrue(Write.text("say \"this\"") == "\"say \\\"this\\\"\"");
        Assert.assertTrue(Write.text("a\\b") == "\"a\\\\b\"");
        // A newline becomes two characters, so the quoted word is six long.
        Assert.assertTrue(String.length(Write.text("a\nb")) == 6)

    // -------------------------------------------------------------------- the layout

    @Test
    def testTheFileIsOneCollectionOfTwoFeatures(): Unit \ Assert =
        let file = written("cota", drawn());
        // The outline first, because it is the line the drawing is measured along.
        says("{\"type\": \"FeatureCollection\", \"features\": [\n    {\n      \"type\": \"Feature\",\n", file);
        says("\n]}\n", file);
        // The pit lane follows the outline's closing brace, and nothing follows it: two
        // features, in the order every reader of the profile expects them.
        says("\"coordinates\":[[-97.638,30.13],[-97.637,30.13]]}\n    }\n]}\n", file);
        // One line per property, and one line each for the coordinates and the metres: a
        // refreshed survey reads as two changed lines per feature rather than as a file
        // that changed all the way down.
        match file {
            case Ok(text) => Assert.assertTrue(List.length(String.lines(text)) == 30)
            case Err(problem) => Assert.assertTrueWithMsg(false, "the writer refused: ${problem}")
        }

    @Test
    def testTheOutlineClaimsWhatTheSurveyKnows(): Unit \ Assert =
        let file = written("cota", drawn());
        // The claims are in the file's own order, and the order is the file's: a kept
        // geometry is diffed by people as much as read by the app.
        says(
            "        \"role\": \"outline\",\n        \"circuit\": \"cota\",\n        \"basis\": \"osm-centreline\",\n        \"source\": \"https://www.openstreetmap.org/relation/6537729\",\n        \"license\": \"ODbL\",\n        \"surveyed_at\": \"2026-10-20T07:01:01Z\",\n        \"direction\": \"counter_clockwise\",\n        \"lap_length_m\": 5515,\n        \"surveyed_length_m\": 5502.238574528194,\n",
            file
        );
        // The frame the degrees project through, whole, and the metres point for point
        // beside the places they were measured to.
        says("        \"frame\": {\"origin\":{\"lat\":30.1394338,\"lon\":-97.6434495},\"parallel\":30.135089049999973},\n", file);
        says("        \"metres\": [0,27.8,5515]\n", file);
        // The degrees, lon before lat, the lap closing back onto its own first place.
        says("      \"geometry\": {\"type\":\"LineString\",\"coordinates\":[[-97.6434495,30.1394338],[-97.6422583,30.1335278],[-97.6,30.1]]}\n", file)

    @Test
    def testTheTimingLinesTravelWithTheGeometryOnlyWhenTheCircuitPublishesThem(): Unit \ Assert =
        // COTA publishes one map for every season, so its authored stretches travel; Le
        // Mans's map answers for one season only, and its geometry writes no `sectors` at
        // all rather than one season's lines as though they served every one.
        says(
            "        \"sectors\": {\"source\":\"the circuit's own track sector map\",\"stretches\":[1313.2,2254.3,1947.5]},\n",
            written("cota", drawn())
        );
        saysNot("sectors", written("le_mans", drawn()))

    @Test
    def testAClaimNothingMadeIsLeftUnwritten(): Unit \ Assert =
        let file = written("le_mans", unstamped());
        // Absent rather than null: a null is a claim about what the answer said, and these
        // are claims no answer made.
        saysNot("surveyed_at", file);
        saysNot("surveyed_length_m", file);
        saysNot("null", file);
        // What the survey counted is the survey's own working, and is written nowhere: a
        // read-back file can say what came out of the writer and not what went into it.
        saysNot("kept", file);
        // What is claimed of every centreline is claimed here too, and the direction the
        // chained survey runs is claimed by the file rather than left to the drawing.
        says("\"direction\": \"clockwise\"", file)

    // -------------------------------------------------------------------- the argument

    @Test
    def testParseWantsACircuitAndTakesTheAnswerWhereTheCircuitKeepsIt(): Unit \ Assert =
        match Write.parse("cota" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#circuit#word == "cota");
                Assert.assertTrue(asked#answer == "circuits/cota/overpass.json");
                // The answer taken from the circuit's directory is not one the reader asked
                // for, which is what tells a circuit nobody has surveyed from a file that
                // cannot be read.
                Assert.assertTrue(not asked#asked);
                Assert.assertTrue(not asked#write)
        }

    @Test
    def testParseRefusesWhatItCannotSurvey(): Unit \ Assert =
        Assert.assertTrue(refused(Write.usage(), Write.parse(Nil)));
        Assert.assertTrue(refused("no circuit is surveyed under 'monza': known are cota, le_mans", Write.parse("monza" :: Nil)));
        Assert.assertTrue(refused("--answer names no file to read", Write.parse("--answer" :: Nil)));
        // A flag is no file: `--answer --write` is a reader who meant something else, and
        // the survey that read it as a path would report a file that cannot be opened.
        Assert.assertTrue(refused("--answer names no file to read", Write.parse("cota" :: "--answer" :: "--write" :: Nil)));
        Assert.assertTrue(refused("\"--froze\" is no flag of this command", Write.parse("cota" :: "--froze" :: Nil)))

    @Test
    def testParseTakesAnAnswerNamedElsewhereAndLaysTheFileDown(): Unit \ Assert =
        match Write.parse("le_mans" :: "--answer" :: "elsewhere/answer.json" :: "--write" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#answer == "elsewhere/answer.json");
                // A named answer is one the reader asked for: if it cannot be read, that is
                // the failure, and not a circuit nobody has surveyed yet.
                Assert.assertTrue(asked#asked);
                Assert.assertTrue(asked#write)
        }

    // ----------------------------------------------------------------------- the parting

    @Test
    def testFirstPartSaysWhereTwoFilesPart(): Unit \ Assert =
        // The reading of a drift is where the bytes part and what each side says there, not
        // the whole file.
        Assert.assertTrue(Write.firstPart("one\ntwo\n", "one\ntwo\n") == "the two files are the same bytes after all");
        Assert.assertTrue(Write.firstPart("one\ntwo\n", "one\nthree\n") == "line 2 is \"three\" in the file, \"two\" from the answer");
        Assert.assertTrue(
            Write.firstPart("one\ntwo\nthree\n", "one\n") == "the files part at line 2, where one of them has nothing left"
        )

    @Test
    def testAPartingQuotesALineOnlyAsFarAsItIsWorthReading(): Unit \ Assert =
        // Two of a geometry's lines are thousands of numbers long; a metre that moved is
        // found by where it moved, not by the eleven thousand digits around it.
        let long = String.repeat(400, "1234");
        let part = Write.firstPart("${long}\n", "1234\n");
        Assert.assertTrue(String.startsWith({prefix = "line 1 is \"1234\" in the file, \"12341234"}, part));
        Assert.assertTrue(String.endsWith({suffix = "…\" from the answer"}, part));
        Assert.assertTrue(String.length(part) < 300)

    /// A refusal that says what the reader asked for, which is the only thing a command can
    /// say to someone at a terminal.
    def refused(problem: String, asked: Result[String, Write.Args]): Bool =
        match asked {
            case Err(one) => String.contains({substr = problem}, one)
            case Ok(_)    => false
        }
}
