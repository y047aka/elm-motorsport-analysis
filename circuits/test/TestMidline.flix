/// The atlas line's shape checks and guards on features built here: what passes as a
/// line, a place or a fraction of a lap; what keeps one circuit's evidence from being
/// filed as another's; and the file that comes out the other end. The lap-origin guard
/// holds the same question `TestSurvey` asks of a relation's finish node, at the wider
/// allowance a measured line is kept to.
pub mod TestMidline {

    use Geodesy.Place

    /// A feature, from the JSON a layer file would hold it in. The one feature of a
    /// file with one feature is what every reading below is handed.
    /// A feature, from the JSON a layer file would hold it in. A fixture that holds
    /// no feature reads as a feature that carries nothing, which every guard below
    /// refuses — a broken fixture fails loudly at the reading, not silently here.
    def feature(json: String): Geometry.Feature =
        match Util.Json.parse("{\"type\": \"FeatureCollection\", \"features\": [ ${json} ]}") {
            case Ok(file) => Option.getWithDefault(Map.empty(), List.head(Geometry.featuresOf(file)))
            case Err(_)   => Map.empty()
        }

    def outlined(properties: String, coordinates: String): Geometry.Feature =
        feature("{ \"properties\": { ${properties} }, \"geometry\": { \"type\": \"LineString\", \"coordinates\": ${coordinates} } }")

    def pointed(properties: String, coordinates: String): Geometry.Feature =
        feature("{ \"properties\": { ${properties} }, \"geometry\": ${coordinates} }")

    /// A reading's failure, or the absence of one.
    def complains(phrase: String, asked: Result[String, a]): Bool =
        match asked {
            case Err(problem) => String.contains({substr = phrase}, problem)
            case Ok(_)        => false
        }

    @Test
    def testLineOfTakesAnOutlineLineAndRefusesAnythingWithoutOne(): Unit \ Assert =
        match Midline.lineOf(outlined(" \"role\": \"outline\"", "[[-97.6, 30.1], [-97.61, 30.11]]")) {
            case Ok(line) =>
                Assert.assertTrue(List.length(line) == 2);
                let first = Option.getWithDefault({lon = 0.0, lat = 0.0}, List.head(line));
                Assert.assertTrue(first#lon == -97.6);
                Assert.assertTrue(first#lat == 30.1)
            case Err(problem) => Assert.assertTrueWithMsg(false, "a line was held: ${problem}")
        };
        Assert.assertTrue(
            complains(
                "the atlas outline holds no line to measure",
                Midline.lineOf(outlined("\"role\": \"outline\"", "[]"))
            )
        );
        Assert.assertTrue(
            complains(
                "holds no line to measure",
                Midline.lineOf(outlined("\"role\": \"outline\"", "[[-97.6, 30.1]]"))
            )
        );
        // One point is not a line; a coordinate that is not a pair of degrees refuses the
        // line at its own position, and the file is refused whole rather than measured
        // with a hole.
        Assert.assertTrue(
            complains(
                "the atlas outline is not a pair of degrees at position 1",
                Midline.lineOf(outlined("\"role\": \"outline\"", "[[\"far\", 30.1], [-97.61, 30.11]]"))
            )
        );
        // The elevation a file records after the pair is nothing to a line.
        match Midline.lineOf(outlined("\"role\": \"outline\"", "[[-97.6, 30.1, 5.0], [-97.61, 30.11, 6.0]]")) {
            case Ok(line)     => Assert.assertTrue(List.length(line) == 2)
            case Err(problem) => Assert.assertTrueWithMsg(false, "an elevation is still a pair of degrees: ${problem}")
        }

    @Test
    def testPlaceOfReadsAMarkersPointAndMarkerOfItsFraction(): Unit \ Assert =
        match Midline.placeOf(pointed("\"role\": \"corner\"", "{ \"coordinates\": [-97.6, 30.1] }")) {
            case Ok(place) =>
                Assert.assertTrue(place#lon == -97.6);
                Assert.assertTrue(place#lat == 30.1)
            case Err(problem) => Assert.assertTrueWithMsg(false, "a point was held: ${problem}")
        };
        // The elevation a file records after the pair changes nothing about where the
        // marker stands.
        match Midline.placeOf(pointed("\"role\": \"corner\"", "{ \"coordinates\": [-97.6, 30.1, 5.0] }")) {
            case Ok(place)    => Assert.assertTrue(place#lon == -97.6)
            case Err(problem) => Assert.assertTrueWithMsg(false, "an elevation is still a place: ${problem}")
        };
        Assert.assertTrue(
            complains(
                "the atlas corner carries no point",
                Midline.placeOf(pointed("\"role\": \"corner\"", "{ }"))
            )
        );
        // A LineString is not a point, whatever role carries it.
        Assert.assertTrue(
            complains(
                "the atlas pit_entry carries no point",
                Midline.placeOf(pointed("\"role\": \"pit_entry\"", "{ \"coordinates\": [[-97.6, 30.1]] }"))
            )
        );
        // A feature that names nothing is called `feature` in the sentence that
        // refuses it — the same name it will be kept under, which is nothing.
        Assert.assertTrue(
            complains(
                "the atlas feature carries no point",
                Midline.placeOf(pointed("{}", "{ \"coordinates\": \"far\" }"))
            )
        );
        match Midline.markerOf(pointed("\"role\": \"corner\", \"marker\": 0.5", "{ \"coordinates\": [-97.6, 30.1] }")) {
            case Ok(fraction) => Assert.assertTrue(fraction == 0.5)
            case Err(problem) => Assert.assertTrueWithMsg(false, "a marker was held: ${problem}")
        };
        // The start of the lap is a real place; zero is a fraction and not an absence.
        Assert.assertTrue(
            Midline.markerOf(pointed("\"role\": \"corner\", \"marker\": 0", "{ \"coordinates\": [-97.6, 30.1] }"))
                == Ok(0.0)
        );
        Assert.assertTrue(
            complains(
                "the atlas corner carries no marker",
                Midline.markerOf(pointed("\"role\": \"corner\"", "{ \"coordinates\": [-97.6, 30.1] }"))
            )
        );
        Assert.assertTrue(
            complains(
                "carries no marker",
                Midline.markerOf(pointed("\"role\": \"corner\", \"marker\": \"half\"", "{ \"coordinates\": [-97.6, 30.1] }"))
            )
        )

    @Test
    def testCheckIdentityRefusesAFileNamingAnotherCircuitAndTrustsAnAnonymousOne(): Unit \ Assert =
        Assert.assertTrue(Midline.checkIdentity(None, "cota") == Ok(()));
        Assert.assertTrue(Midline.checkIdentity(Some("cota"), "cota") == Ok(()));
        Assert.assertTrue(
            complains(
                "the atlas file names itself 'le_mans', not 'cota' — it is not this circuit's line",
                Midline.checkIdentity(Some("le_mans"), "cota")
            )
        )

    @Test
    def testCheckOriginAnswersNoughtForACircuitPublishingNoLine(): Unit \ Assert =
        Assert.assertTrue(Midline.checkOrigin({lon = 0.0, lat = 0.0}, None) == Ok(0.0))

    /// The allowance a measured line is held to is the reading's own. The `within`
    /// a circuit authors is how far a *relation's node* may stand from the published
    /// place — the crosshair of the map the line was copied from — and a line
    /// measured off orthoimagery chooses its own start, so it is not held to it.
    @Test
    def testCheckOriginHoldsTheMeasuredLineToTheReadingsOwnAllowance(): Unit \ Assert =
        let published = {place = {lon = 0.0, lat = 47.0}, within = Some(5.0)};
        // A tenth of a hundredth of a degree walks about eleven metres — past the
        // node's five, inside the reading's twenty-five.
        let candidate = {lon = 0.0, lat = 47.0001};
        Assert.assertTrue(Result.isOk(Midline.checkOrigin(candidate, Some(published))));
        // Ten times as far is past the reading's own allowance, and the refusal
        // quotes that allowance and not the node's.
        Assert.assertTrue(
            complains(
                "not within 25 m",
                Midline.checkOrigin({lon = 0.0, lat = 47.001}, Some(published))
            )
        )

    @Test
    def testCheckOriginKeepsALapStartingAtAnotherLineOut(): Unit \ Assert =
        // COTA's `start` node stands 297 m along the lap from its `finish`; a line
        // measured from it would shift every distance by that and look like a lap.
        let published = {place = {lon = -97.6422583, lat = 30.1335278}, within = None};
        Assert.assertTrue(
            complains(
                "not within 25 m",
                Midline.checkOrigin({lon = -97.6394, lat = 30.1335278}, Some(published))
            )
        );
        // Where the line itself stands is zero, and is Ok of course.
        Assert.assertTrue(
            Result.isOk(Midline.checkOrigin(published#place, Some(published)))
        )

    @Test
    def testSectorLinesAreTheStretchesBetweenTheStretches(): Unit \ Assert =
        let sectors = {source = "a map", stretches = 1313.2 :: 2254.3 :: 1947.5 :: Nil};
        match Midline.sectorLines(sectors, 5515.0) {
            case Ok(lines) =>
                Assert.assertTrue(List.length(lines) == 2);
                // The second sector begins at s2 — the last stretch ends where the
                // lap began, which is the line the lap is measured from and no line.
let second = Option.getWithDefault({id = "", metres = -1.0}, List.nth(0, lines));
                Assert.assertTrue(second#id == "s2" and second#metres == 1313.2);
                let third = Option.getWithDefault({id = "", metres = -1.0}, List.nth(1, lines));
                Assert.assertTrue(third#id == "s3" and third#metres == 3567.5)
            case Err(problem) => Assert.assertTrueWithMsg(false, "the stretches added up: ${problem}")
        };
        Assert.assertTrue(
            complains(
                "the sectors add up to 5000 m, not the published 5515 m",
                Midline.sectorLines({source = "a map", stretches = 2500.0 :: 2500.0 :: Nil}, 5515.0)
            )
        );
        // A map publishing one stretch publishes no intermediate line.
        match Midline.sectorLines({source = "a map", stretches = 5515.0 :: Nil}, 5515.0) {
            case Ok(lines) => Assert.assertTrue(List.isEmpty(lines))
            case Err(problem) => Assert.assertTrueWithMsg(false, "the stretches added up: ${problem}")
        }

    /// An outline's properties, as the file's JSON gives them.
    def propsOf(text: String): Map[String, Util.Json.Json] =
        match Util.Json.parse(text) {
            case Ok(Util.Json.Json.JObject(members)) => members
            case _                                   => Map.empty()
        }

    @Test
    def testSectorsClaimedReadsAWholeClaimAndRefusesHalfOnes(): Unit \ Assert =
        match Midline.sectorsClaimed(propsOf("{ \"sectors\": { \"source\": \"a map\", \"stretches\": [1.0, 2.0] } }")) {
            case Some(held) => Assert.assertTrue(held#source == "a map" and held#stretches == (1.0 :: 2.0 :: Nil))
            case None       => Assert.assertTrueWithMsg(false, "the claim was whole")
        };
        // Half a claim is no claim: what a reading does with one is measure as if no
        // map were published.
        Assert.assertTrue(Option.isEmpty(Midline.sectorsClaimed(propsOf("{ \"sectors\": { \"stretches\": [1.0, 2.0] } }"))));
        Assert.assertTrue(Option.isEmpty(Midline.sectorsClaimed(propsOf("{}"))))

    @Test
    def testFileTextWritesTheAtlasLineAtItsOwnLengthSayingSo(): Unit \ Assert =
        let corners = pointed("\"role\": \"corner\", \"id\": \"T1\", \"marker\": 0.02, \"direction\": \"right\"", "{ \"type\": \"Point\", \"coordinates\": [-97.605, 30.105] }") :: Nil;
        let pits = pointed("\"role\": \"pit_entry\", \"name\": \"Pit Entry\", \"marker\": 0.95", "{ \"type\": \"Point\", \"coordinates\": [-97.615, 30.115] }") :: Nil;
        let coords = {lon = -97.6, lat = 30.1} :: {lon = -97.61, lat = 30.11} :: {lon = -97.62, lat = 30.12} :: Nil;
        let written = Midline.file("https://example.org/cota.geojson", "cota", coords, corners, pits, 0.0 :: 2750.14 :: 5500.23 :: Nil);
        // A measurement is not mistaken for a survey, and does not end at the
        // published lap length — the file says so at the properties a reader sees first.
        Assert.assertTrue(String.contains({substr = "\"basis\":\"measured-midline\""}, written));
        Assert.assertTrue(String.contains({substr = "\"stretched\":false"}, written));
        Assert.assertTrue(String.contains({substr = "\"lap_length_m\":5500.2"}, written));
        Assert.assertTrue(String.contains({substr = "\"metres\":[0,2750.1,5500.2]"}, written));
        Assert.assertTrue(String.contains({substr = "\"source\":\"https://example.org/cota.geojson\""}, written));
        Assert.assertTrue(String.contains({substr = "\"license\":\"ODbL\""}, written));
        // A corner keeps its id, its fraction and which way it turns; a pit keeps
        // the role the layer gave it, its name and its fraction.
        Assert.assertTrue(String.contains({substr = "\"properties\":{\"role\":\"corner\",\"id\":\"T1\",\"marker\":0.02,\"direction\":\"right\"}"}, written));
        Assert.assertTrue(String.contains({substr = "\"properties\":{\"role\":\"pit_entry\",\"name\":\"Pit Entry\",\"marker\":0.95}"}, written));
        // The degrees keep the digits the layer spelled, lon before lat.
        Assert.assertTrue(String.contains({substr = "{\"type\":\"Point\",\"coordinates\":[-97.605,30.105]}"}, written));
        // One line per feature, four spaces deep, as every kept atlas file stands.
        Assert.assertTrue(String.contains({substr = "\n    {\"type\":\"Feature\",\"properties\":{\"role\":\"outline\""}, written))

    @Test
    def testFileTextCarriesNoPropertyTheLayerDidNotHold(): Unit \ Assert =
        let bare = pointed("\"role\": \"corner\"", "{ \"type\": \"Point\", \"coordinates\": [-97.605, 30.105] }") :: Nil;
        let written = Midline.file("https://example.org/cota.geojson", "cota", {lon = -97.6, lat = 30.1} :: {lon = -97.61, lat = 30.11} :: Nil, bare, Nil, 0.0 :: 100.0 :: Nil);
        // An undefined property is no key at all — and the null the layer did hold
        // stays a null, which is what the reading that keeps a file never invents.
        Assert.assertTrue(not String.contains({substr = "\"id\""}, written));
        Assert.assertTrue(not String.contains({substr = "\"marker\""}, written));
        Assert.assertTrue(not String.contains({substr = "null,\"marker\""}, written))

    @Test
    def testSignedSaysWhichLineIsLonger(): Unit \ Assert =
        Assert.assertTrue(Midline.signed(1.23) == "+1.2");
        Assert.assertTrue(Midline.signed(-0.04) == "-0.0");
        Assert.assertTrue(Midline.signed(0.0) == "+0.0")
}
