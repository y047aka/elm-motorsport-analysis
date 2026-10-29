/// The reading of a kept geometry file: the outline as the line it claims to be, and the
/// refusals a file with a survey that means something different to the reader than to the
/// fence would otherwise pass unseen. Every command that reads a kept file reads it
/// through the module these tests hold: the diff, the atlas reading, the regeneration
/// fence.
pub mod TestGeometry {

    use Geometry.Line

    /// A file of one feature, written the way a geometry file writes it: a role inside the
    /// properties, the coordinates in the geometry, lon before lat.
    def file(features: String): String =
        "{" + "\n  \"type\": \"FeatureCollection\"," + "\n  \"features\": [ ${features} ]" + "\n}"

    def outlineWith(properties: String, coordinates: String): String =
        feature("outline", properties, coordinates)

    /// A feature of one role. A line with no properties beside its role is written
    /// without a trailing comma, which is the one thing a hand-written fixture can get
    /// wrong and have every refusal read as a parse failure instead.
    def feature(role: String, properties: String, coordinates: String): String = {
        let props =
            if (properties == "")
                "{ \"role\": \"${role}\" }"
            else
                "{ \"role\": \"${role}\", ${properties} }";
        "{"
            + " \"type\": \"Feature\","
            + " \"properties\": ${props},"
            + " \"geometry\": { \"type\": \"LineString\", \"coordinates\": ${coordinates} }"
            + " }"
    }

    /// GeoJSON gives a line's coordinates as one array of positions.
    def line(positions: String): String =
        "[ ${positions} ]"

    def surveyed(name: String): Result[String, Line] =
        Geometry.outline(
            name,
            file(
                outlineWith(
                    "\"basis\": \"osm-centreline\", \"source\": \"https://www.openstreetmap.org/relation/999\", \"metres\": [0, 100]",
                    line("[0, 0], [100, 0]")
                )
            )
        )

    /// A reading's failure, or the absence of one.
    def refused(phrase: String, read: Result[String, a]): Bool =
        match read {
            case Err(problem) => String.contains({substr = phrase}, problem)
            case Ok(_)        => false
        }

    def outlineRefusing(properties: String, coordinates: String): Result[String, Line] =
        Geometry.outline("cota", file(outlineWith(properties, line(coordinates))))

    @Test
    def testOutlineTakesTheLineAFileClaimsItIs(): Unit \ Assert =
        match surveyed("cota") {
            case Ok(line) =>
                Assert.assertTrue(line#name == "cota");
                Assert.assertTrue(line#props#basis == "osm-centreline");
                Assert.assertTrue(line#props#source == Some("https://www.openstreetmap.org/relation/999"));
                Assert.assertTrue(List.length(line#coords) == 2);
                // The degrees are the file's own, lon first, and the metres leave the
                // properties on the way through.
                Assert.assertTrue(Option.map(place -> place#lon, List.nth(0, line#coords)) == Some(0.0));
                Assert.assertTrue(Option.map(place -> place#lat, List.nth(1, line#coords)) == Some(0.0));
                Assert.assertTrue(line#metres == 0.0 :: 100.0 :: Nil)
            case Err(problem) => Assert.assertTrueWithMsg(false, "read the file: ${problem}")
        }

    @Test
    def testOutlineRefusesABasisItDoesNotKnowAndAFileThatNamesNone(): Unit \ Assert =
        Assert.assertTrue(
            refused(
                "cota: the outline names basis \"measured-by-hand\", which is not a line this repository reads",
                outlineRefusing("\"basis\": \"measured-by-hand\", \"metres\": [0, 100]", "[0, 0], [100, 0]")
            )
        );
        Assert.assertTrue(
            refused(
                "cota: the outline names basis nothing, which is not a line this repository reads",
                outlineRefusing("\"metres\": [0, 100]", "[0, 0], [100, 0]")
            )
        )

    @Test
    def testOutlineRefusesAFileWhoseClaimsAndPointsDisagree(): Unit \ Assert =
        // Every failure names the file it was reading, because a diff reads two of them
        // and a reader cannot otherwise tell which one moved.
        Assert.assertTrue(
            refused(
                "cota: 3 metres for 2 points",
                outlineRefusing("\"basis\": \"osm-centreline\", \"metres\": [0, 100, 200]", "[0, 0], [100, 0]")
            )
        );
        Assert.assertTrue(
            refused("cota: the outline publishes no metres", outlineRefusing("\"basis\": \"osm-centreline\"", "[0, 0], [100, 0]"))
        );
        Assert.assertTrue(
            refused(
                "cota: the outline holds no points to draw",
                outlineRefusing("\"basis\": \"osm-centreline\", \"metres\": []", "")
            )
        );
        Assert.assertTrue(
            refused(
                "cota: metres go backwards at point 2",
                outlineRefusing("\"basis\": \"osm-centreline\", \"metres\": [0, 200, 100]", "[0, 0], [100, 0], [50, 0]")
            )
        )

    @Test
    def testOutlineRefusesAFileWithNoOutlineAtAll(): Unit \ Assert =
        Assert.assertTrue(
            refused(
                "cota: the geometry holds no outline feature",
                Geometry.outline("cota", file(feature("pit_lane", "", line("[0, 0]"))))
            )
        );
        Assert.assertTrue(
            refused(
                "cota: the geometry holds no outline feature",
                Geometry.outline("cota", "{\"type\": \"FeatureCollection\"}"))
        )

    @Test
    def testPitLaneIsALineWithNoMetresBecauseNothingTimesAlongIt(): Unit \ Assert =
        let both = file(
            outlineWith("\"basis\": \"osm-centreline\", \"metres\": [0, 100]", line("[0, 0], [100, 0]"))
                + ", "
                + feature("pit_lane", "", line("[0, 0], [10, 0]"))
        );
        match Geometry.pitLane("cota", both) {
            case Ok(pit)      => Assert.assertTrue(List.length(pit) == 2)
            case Err(problem) => Assert.assertTrueWithMsg(false, "read the pit lane: ${problem}")
        }

    @Test
    def testPitLaneRefusesAGeometryWithNoneAndALineWithNoCoordinates(): Unit \ Assert =
        Assert.assertTrue(
            refused(
                "cota: the geometry holds no pit lane feature",
                Geometry.pitLane("cota", file(outlineWith("\"basis\": \"osm-centreline\", \"metres\": [0, 100]", "[0, 0]")))
            )
        );
        // An empty position is not a pair of degrees, and is refused where it stands.
        Assert.assertTrue(
            refused(
                "cota: the pit lane is not a pair of degrees at position 1",
                Geometry.pitLane("cota", file(feature("pit_lane", "", line("[]"))))
            )
        )

    @Test
    def testAMissingNumberIsNotALineWithAHoleInIt(): Unit \ Assert =
        // A `metres` array holding something that is not a number published a metre
        // the reading could not read — which is not the same file as one that
        // published no metres at all, and is refused with the entry it stumbled at.
        Assert.assertTrue(
            refused(
                "cota: metres entry 1 is not a number",
                outlineRefusing("\"basis\": \"osm-centreline\", \"metres\": [0, \"far\"]", "[0, 0], [100, 0]")
            )
        );
        // A coordinate that is not a pair of degrees refuses the line at the position it
        // was written at — not a shorter line, and not a disagreement with the metres
        // counted after the fact.
        Assert.assertTrue(
            refused(
                "cota: the outline is not a pair of degrees at position 2",
                outlineRefusing("\"basis\": \"osm-centreline\", \"metres\": [0, 100]", "[0, 0], [\"far\", 0]")
            )
        )
}
