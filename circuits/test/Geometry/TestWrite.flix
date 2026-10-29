/// The geometry file as bytes: the spelling a number is given, the claims a circuit does not
/// make left unwritten, and the layout every reader of a kept file reads. Which answer these
/// are written from, and whether they are laid down at all, is the `survey` word's and is
/// `TestSurvey`'s; CI asks the word of both circuits on every run.
pub mod Geometry.TestWrite {

    use Circuit.Circuit
    use Geodesy.Place

    // ------------------------------------------------------------------ the fixtures

    /// A line of three places, at the metres a survey stretched to the published lap ends
    /// them at: the first at the line the lap is timed from, the last at the circuit's own
    /// length. Nothing is asked of the sphere here, since these are the metres the file
    /// carries rather than metres measured here again.
    def lap(): List[Geodesy.Metred] =
        {place = {lat = 30.1394338, lon = -97.6434495}, metre = 0.0} :: {
            place = {lat = 30.1335278, lon = -97.6422583},
            metre = 27.8
        } :: {place = {lat = 30.1, lon = -97.6}, metre = 5515.0} :: Nil

    /// The pit lane, which carries no metres because nothing times along it.
    def pit(): List[Place] =
        {lat = 30.13, lon = -97.638} :: {lat = 30.13, lon = -97.637} :: Nil

    def frame(): Geodesy.Frame = {
        origin = {lat = 30.1394338, lon = -97.6434495},
        parallel = 30.135089049999973
    }

    /// A geometry as the survey hands one over: stamped and measured.
    def drawn(): Survey.Geometry = {
        centreline = lap(),
        pitLane = pit(),
        frame = frame(),
        direction = Survey.counterClockwise(),
        surveyedAt = Some("2026-10-20T07:01:01Z"),
        surveyedLength = Some(5502.238574528194)
    }

    /// The same line from an answer that said nothing about itself.
    def unstamped(): Survey.Geometry = {
        centreline = lap(),
        pitLane = pit(),
        frame = frame(),
        direction = Survey.clockwise(),
        surveyedAt = None,
        surveyedLength = None
    }

    /// The file a circuit's survey would write, or the sentence that refused to write one.
    def written(word: String, geometry: Survey.Geometry): Result[String, String] =
        match Circuit.byWord(word) {
            case None       => Err("the test names no circuit")
            case Some(circuit) => Ok(Geometry.Write.file(circuit, geometry))
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
        Assert.assertTrue(Geometry.Write.number(5515.0) == "5515");
        Assert.assertTrue(Geometry.Write.number(0.0) == "0");
        Assert.assertTrue(Geometry.Write.number(1313.2) == "1313.2");
        Assert.assertTrue(Geometry.Write.number(-97.6) == "-97.6");
        Assert.assertTrue(Geometry.Write.number(30.135089049999973) == "30.135089049999973")

    @Test
    def testAWordIsQuotedAndEscaped(): Unit \ Assert =
        // A sector map's name carries an apostrophe, which JSON carries as itself; a quote,
        // a backslash and a newline are the three a word cannot hold unescaped.
        Assert.assertTrue(Geometry.Write.text("the circuit's own track sector map") == "\"the circuit's own track sector map\"");
        Assert.assertTrue(Geometry.Write.text("say \"this\"") == "\"say \\\"this\\\"\"");
        Assert.assertTrue(Geometry.Write.text("a\\b") == "\"a\\\\b\"");
        // A newline becomes two characters, so the quoted word is six long.
        Assert.assertTrue(String.length(Geometry.Write.text("a\nb")) == 6)

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
}
