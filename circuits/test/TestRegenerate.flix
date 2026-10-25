/// The regeneration fence's comparison: what counts as the same drawing from a
/// different run, what counts as the drawing having moved, and which single
/// property a live regeneration is allowed to move — and the coverage of the
/// comparison over the file the project's own writer lays.
pub mod TestRegenerate {

    use Circuit.Circuit
    use Geometry.Place
    use Regenerate.Mode
    use Util.Json.Json

    // ------------------------------------------------------------------ the fixtures

    /// The lap of the fixture file, as the file gives it: degrees, lon before lat.
    def places(): String =
        "[0,47],[0.01,47],[0.01,46.99]"

    /// The same lap with the second place moved along the line — the same drawing
    /// is not the same degrees.
    def movedPlaces(): String =
        "[0,47],[0.011,47],[0.01,46.99]"

    /// A feature of these properties and these coordinates, as a geometry file
    /// lays one out.
    def featureWith(properties: String, coordinates: String): String =
        "{\"properties\":{${properties}},\"geometry\":{\"type\":\"LineString\",\"coordinates\":[${coordinates}]}}"

    def pitFeature(): String =
        featureWith("\"role\":\"pit_lane\",\"circuit\":\"test_circuit\"", "[0.01,47],[-0.002,46.995]")

    def collection(features: List[String]): String =
        "{\"type\":\"FeatureCollection\",\"features\":[${String.intercalate(",", features)}]}"

    /// One outline and one pit lane, stamped `at`, with the outline standing at
    /// `end` metres.
    def file(at: String): String =
        withPlaces(at, 4000.0, places())

    def withEnd(at: String, end: Float64): String =
        withPlaces(at, end, places())

    def withPlaces(at: String, end: Float64, coordinates: String): String =
        collection(
            featureWith(
                "\"role\":\"outline\",\"circuit\":\"test_circuit\",\"surveyed_at\":\"${at}\",\"metres\":[0,2000,${Write.number(end)}]",
                coordinates
            ) :: pitFeature() :: Nil
        )

    /// The same file with the outline's coordinates spelled with a decimal on
    /// every metre: the same metres, held by a writer that spelled them
    /// differently.
    def spelledEnd(): String =
        collection(
            featureWith(
                "\"role\":\"outline\",\"circuit\":\"test_circuit\",\"metres\":[0.0,2000.0,4000.0]",
                places()
            ) :: pitFeature() :: Nil
        )

    /// The file minus the outline's claim about which circuit it is.
    def stripped(): String =
        collection(
            featureWith("\"role\":\"outline\",\"surveyed_at\":\"x\",\"metres\":[0,2000,4000]", places())
                :: pitFeature() :: Nil
        )

    /// The file with no pit lane at all.
    def outlineOnly(): String =
        collection(
            featureWith("\"role\":\"outline\",\"circuit\":\"test_circuit\",\"surveyed_at\":\"x\",\"metres\":[0,2000,4000]", places()) :: Nil
        )
    def drifted(fresh: String, kept: String): Result[String, List[String]] =
        Regenerate.driftOf(fresh, kept)

    // ---------------------------------------------------------------- the comparison

    @Test
    def testAFileReproducesItselfAndOnlyTheSurveyStampMayDiffer(): Unit \ Assert =
        Assert.assertTrue(drifted(file("2026-01-01T00:00:00Z"), file("2026-01-01T00:00:00Z")) == Ok(Nil));
        // The exemption's whole point: a regeneration that asks OpenStreetMap now takes
        // a newer survey while every degree stands still.
        Assert.assertTrue(drifted(file("2026-06-01T00:00:00Z"), file("2026-01-01T00:00:00Z")) == Ok(Nil))

    @Test
    def testAMovedDegreeIsDriftNamedByFeatureAndPoint(): Unit \ Assert =
        Assert.assertTrue(
            drifted(withPlaces("x", 4000.0, movedPlaces()), file("x"))
                == Ok("outline: the line's points differ at point 1" :: Nil)
        )

    @Test
    def testAChangedPropertyIsDriftQuotedFromBothSides(): Unit \ Assert =
        Assert.assertTrue(
            drifted(withEnd("x", 4100.0), file("x"))
                == Ok("outline: metres is [0,2000,4000] in the file, [0,2000,4100] from the answer" :: Nil)
        );
        Assert.assertTrue(
            drifted(stripped(), file("x"))
                == Ok("outline: circuit is \"test_circuit\" in the file, absent from the answer" :: Nil)
        );
        // The same parting read from the other side quotes the other absence.
        Assert.assertTrue(
            drifted(file("x"), stripped())
                == Ok("outline: circuit is absent in the file, \"test_circuit\" from the answer" :: Nil)
        )

    @Test
    def testAFeatureHeldByOnlyOneSideIsNamedByRole(): Unit \ Assert =
        Assert.assertTrue(drifted(file("x"), outlineOnly()) == Ok("pit_lane: only the regeneration holds it" :: Nil));
        Assert.assertTrue(drifted(outlineOnly(), file("x")) == Ok("pit_lane: only the kept file holds it" :: Nil))

    @Test
    def testAMetreIsComparedByValueAndNotBySpelling(): Unit \ Assert =
        // A kept file written by one writer and a survey laid by another may spell the
        // same metre `4000` and `4000.0`; that is not a drawing that moved.
        Assert.assertTrue(drifted(file("x"), spelledEnd()) == Ok(Nil))

    @Test
    def testAFileThatStopsBeingJSONIsRefused(): Unit \ Assert =
        Assert.assertTrue(refused("the regenerated file does not parse", drifted("not json", file("x"))));
        Assert.assertTrue(refused("the kept file does not parse", drifted(file("x"), "{\"type\":")))

    @Test
    def testDriftKeepsAskingAfterTheFirstMovedDrawing(): Unit \ Assert =
        // Two features moved: the report says both, since a reader fixing one wants to
        // know whether the rest of the file stands.
        let both =
            collection(
                featureWith("\"role\":\"outline\",\"circuit\":\"other\",\"metres\":[0,2000,4000]", movedPlaces())
                    :: featureWith("\"role\":\"pit_lane\",\"circuit\":\"test_circuit\"", "[0.01,47]") :: Nil
            );
        match drifted(both, file("x")) {
            case Ok(drift) =>
                Assert.assertTrue(drift == List#{
                    "outline: the line's points differ at point 1",
                    "outline: circuit is \"test_circuit\" in the file, \"other\" from the answer",
                    "pit_lane: the line's points differ at point 1"
                })
            case Err(problem) => Assert.assertTrueWithMsg(false, "the fence refused: ${problem}")
        }

    // ------------------------------------------------------------------- the reading

    @Test
    def testComparedCoversEveryClaimTheWriterLays(): Unit \ Assert =
        // What the fence asks of the outline is every claim the writer lays, the stamp
        // alone exempt. The order of the report is the writer's own and is read off
        // `compared`'s source; what a parsed file cannot say is the order its keys came
        // in, so what this test holds is the coverage: a claim the writer one day adds
        // and `compared` does not is caught here as a difference of two sorted lists —
        // the claim order itself is `TestWrite`'s to hold against the bytes.
        let written = writtenFile();
        match outlineKeys(written) {
            case None => Assert.assertTrueWithMsg(false, "the written file holds no outline to read")
            case Some(keys) =>
                Assert.assertTrue(List.sort(keys) == List.sort(Regenerate.compared() ++ ("surveyed_at" :: Nil)))
        };
        Assert.assertTrue(drifted(written, written) == Ok(Nil))

    /// The file the writer would lay for COTA, from the survey a kept answer
    /// draws — the same fixture `TestWrite` lays its bytes from.
    def writtenFile(): String =
        match Circuit.byWord("cota") {
            case None          => ""
            case Some(circuit) => Write.geoJson(circuit, drawn())
        }

    def lap(): List[Survey.MetredPlace] =
        {lat = 30.1394338, lon = -97.6434495, metres = 0.0} :: {
            lat = 30.1335278,
            lon = -97.6422583,
            metres = 27.8
        } :: {lat = 30.1, lon = -97.6, metres = 5515.0} :: Nil

    def pit(): List[Place] =
        {lat = 30.13, lon = -97.638} :: {lat = 30.13, lon = -97.637} :: Nil

    def frame(): Survey.Frame = {
        origin = {lat = 30.1394338, lon = -97.6434495},
        parallel = 30.135089049999973
    }

    def drawn(): Survey.Geometry = {
        centreline = lap(),
        pitLane = pit(),
        frame = frame(),
        direction = Survey.counterClockwise(),
        surveyedAt = Some("2026-10-20T07:01:01Z"),
        surveyedLength = Some(5502.238574528194)
    }

    /// The outline's property keys — a parsed file keeps them sorted, not in the
    /// order they were written in.
    def outlineKeys(text: String): Option[List[String]] =
        match Util.Json.parse(text) {
            case Err(_) => None
            case Ok(json) =>
                match List.find(isOutline, Geometry.featuresOf(json)) {
                    case None       => None
                    case Some(one)  => Some(keysOf(Geometry.propertiesOf(one)))
                }
        }

    def isOutline(feature: Map[String, Json]): Bool =
        Geometry.word("role", Geometry.propertiesOf(feature)) == Some("outline")

    def keysOf(props: Map[String, Json]): List[String] =
        List.map(pair -> match pair {case (key, _) => key}, Map.toList(props))

    // -------------------------------------------------------------------- the argument

    @Test
    def testParseWalksEveryCircuitWhenNamedNone(): Unit \ Assert =
        match Regenerate.parse(Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#mode == Mode.Compare);
                Assert.assertTrue(List.map(c -> c#word, asked#circuits) == List.map(c -> c#word, Circuit.circuits()))
        }

    @Test
    def testParseKeepsTheReadersOwnOrder(): Unit \ Assert =
        match Regenerate.parse("le_mans" :: "cota" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(List.map(c -> c#word, asked#circuits) == List#{"le_mans", "cota"})
        }

    @Test
    def testParseRefusesWhatAnswersForNoRun(): Unit \ Assert =
        Assert.assertTrue(
            refused(
                "--write and --freeze ask for opposite things",
                Regenerate.parse("--write" :: "--freeze" :: Nil)
            )
        );
        Assert.assertTrue(
            refused("no circuit is surveyed under 'monza': known are cota, le_mans", Regenerate.parse("monza" :: Nil))
        );
        Assert.assertTrue(refused("\"--froze\" is no flag of this command", Regenerate.parse("--froze" :: Nil)))

    @Test
    def testParseReadsWhatAFenceDoesWithItsCircuits(): Unit \ Assert =
        match Regenerate.parse("cota" :: "--write" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#mode == Mode.Write);
                Assert.assertTrue(List.length(asked#circuits) == 1)
        };
        match Regenerate.parse("cota" :: "--freeze" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) => Assert.assertTrue(asked#mode == Mode.Freeze)
        }

    /// A refusal that says what the reader asked for.
    def refused(phrase: String, asked: Result[String, a]): Bool =
        match asked {
            case Err(problem) => String.contains({substr = phrase}, problem)
            case Ok(_)        => false
        }
}
