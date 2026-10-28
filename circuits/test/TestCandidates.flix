/// The probe's readings without the probing: how far a place widens into a box,
/// which tags could name a circuit, what a relation's own tags claim, and what an
/// answer's roles measure. `TestOverpass` drives the other half -- the reading of
/// an answer's text into the elements these are handed.
pub mod TestCandidates {

    import java.lang.Math

    use Candidates.{bboxOf, describe, looksLikeACircuit, measure}
    use Overpass.Element
    use Overpass.Member
    use Overpass.Place
    use Overpass.Tags

    /// The same sphere `Candidates` measures on: a fixture's way is a length in
    /// degrees that can be counted, rather than a survey to keep beside it.
    def degrees(): Float64 = (Math.PI / 180.0) * 6371008.8

    def northOf(metres: Float64): Place = { lat = metres / degrees(), lon = 0.0 }

    def atZero(): Place = { lat = 0.0, lon = 0.0 }

    /// A way whose line runs back to the equator and the prime meridian, so its
    /// length is the one number the fixture wrote it as.
    def way(id: Int64, metres: Float64): Element =
        { id = id, kind = "way", tags = Map.empty(), members = Nil, line = List#{northOf(metres), atZero()} }

    def node(id: Int64): Element =
        { id = id, kind = "node", tags = Map.empty(), members = Nil, line = Nil }

    def member(kind: String, role: String, ref: Int64): Member = { kind = kind, role = role, ref = ref }

    def tag(entries: List[(String, String)]): Tags =
        List.foldLeft(
            (tags, entry) ->
                match entry {
                    case (key, value) => Map.insert(key, value, tags)
                },
            Map.empty(),
            entries
        )

    /// Relation 7 carrying the members a probe reports, with the ways it refers to
    /// beside it.
    def relationWith(members: List[Member], ways: List[Element]): List[Element] =
        List.append(
            List#{ { id = 7i64, kind = "relation", tags = Map.empty(), members = members, line = Nil } },
            ways
        )

    /// Two unroled ways, one pit way and one named node: 300 m of lap, 55 m of pit
    /// lane, and the roles a config is authored from.
    def answer(): List[Element] =
        relationWith(
            List#{
                member("way", "", 1i64),
                member("way", "", 2i64),
                member("way", "pit_lane", 3i64),
                member("node", "start", 4i64)
            },
            List#{way(1i64, 100.0), way(2i64, 200.0), way(3i64, 55.0), node(4i64)}
        )

    /// A reading's failure, or the absence of one.
    def complains(problem: String, asked: Result[String, Candidates.Box]): Bool =
        match asked {
            case Err(reading) => String.contains({substr = problem}, reading)
            case Ok(_)        => false
        }

    def says(line: Result[String, String], phrase: String): Bool =
        match line {
            case Ok(measured) => String.contains({substr = phrase}, measured)
            case Err(_)       => false
        }

    @Test
    def testBboxTakesABoxAsGiven(): Unit \ Assert =
        match bboxOf("47.0,0.1,48.0,0.9", 5.0) {
            case Ok(box) =>
                Assert.assertTrue(box#s == 47.0);
                Assert.assertTrue(box#w == 0.1);
                Assert.assertTrue(box#n == 48.0);
                Assert.assertTrue(box#e == 0.9)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testBboxWidensACentreByTheRadius(): Unit \ Assert =
        match bboxOf("47.0,0.0", 5.0) {
            case Ok(box) =>
                // A radius of latitude over 111.32 km per degree, and more degrees
                // of longitude at the same ground distance.
                Assert.assertTrue(Math.abs(box#n - 47.0 - 5.0 / 111.32) < 0.000000001);
                Assert.assertTrue(box#e - 0.0 > box#n - 47.0);
                Assert.assertTrue(Math.abs(box#s + box#n - 94.0) < 0.000000001)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testBboxRefusesABoxThatDoesNotOpenAndAPlaceThatIsNeither(): Unit \ Assert =
        Assert.assertTrue(complains("the box does not open north-east", bboxOf("48.0,0.0,47.0,1.0", 5.0)));
        Assert.assertTrue(complains("neither a centre nor a box", bboxOf("1.0,2.0,3.0", 5.0)));
        Assert.assertTrue(complains("neither a centre nor a box", bboxOf("north,east", 5.0)))

    @Test
    def testLooksLikeACircuitTakesTheTagsAChainableRelationCouldCarry(): Unit \ Assert =
        Assert.assertTrue(looksLikeACircuit(tag(List#{("type", "circuit")})));
        Assert.assertTrue(looksLikeACircuit(tag(List#{("motorsport", "le_mans_series")})));
        Assert.assertTrue(looksLikeACircuit(tag(List#{("highway", "raceway")})));
        Assert.assertTrue(looksLikeACircuit(tag(List#{("sport", "motorsport")})));
        Assert.assertTrue(looksLikeACircuit(tag(List#{("type", "route"), ("route", "raceway")})));
        Assert.assertTrue(
            looksLikeACircuit(tag(List#{("type", "route"), ("route", "walking"), ("raceway:pit_lane", "yes")})))

    @Test
    def testLooksLikeACircuitRefusesWhatACatchOfTheBoxCouldBe(): Unit \ Assert =
        Assert.assertTrue(not looksLikeACircuit(tag(List#{("type", "boundary")})));
        Assert.assertTrue(not looksLikeACircuit(tag(List#{("sport", "soccer")})));
        // A raceway route says so in its route tag.
        Assert.assertTrue(not looksLikeACircuit(tag(List#{("type", "route"), ("route", "bus")})));
        Assert.assertTrue(not looksLikeACircuit(tag(Nil)))

    @Test
    def testDescribePrintsTheKindTheNameAndTheLengthTheTagsClaim(): Unit \ Assert =
        let sarthe = tag(List#{("type", "circuit"), ("name", "Circuit automobile"), ("distance", "13.626")});
        Assert.assertTrue(describe(sarthe) == "type=circuit  \"Circuit automobile\", tags say 13.626 km");

        let cota = tag(List#{("sport", "motor"), ("name:en", "COTA")});
        Assert.assertTrue(describe(cota) == "sport=motor  \"COTA\"");

        // An unnamed relation still prints.
        Assert.assertTrue(describe(tag(List#{("type", "circuit")})) == "type=circuit  \"(unnamed)\"")

    @Test
    def testMeasureCountsTheRolesAndMeasuresTheUnroledWays(): Unit \ Assert =
        let read = measure(answer(), 7i64);
        Assert.assertTrue(says(read, "lap 300 m over 2 unroled ways"));
        Assert.assertTrue(says(read, ", pit 55 m"));
        Assert.assertTrue(says(read, "roles: (none): 2 ways, pit_lane: 1 way"));
        Assert.assertTrue(says(read, "; nodes: start"))

    /// OpenStreetMap has been tagged the pit lane both ways, and a report reading
    /// only one spelling would print a pit lane of nought metres.
    @Test
    def testMeasureReadsThePitRoleWhicheverWayItIsTagged(): Unit \ Assert =
        let spelled = relationWith(
            List#{member("way", "", 1i64), member("way", "", 2i64), member("way", "pit", 3i64)},
            List#{way(1i64, 100.0), way(2i64, 200.0), way(3i64, 55.0)}
        );
        Assert.assertTrue(says(measure(spelled, 7i64), ", pit 55 m"));
        Assert.assertTrue(says(measure(answer(), 7i64), ", pit 55 m"))

    /// A way the relation carries under two roles is the same ground twice, and the
    /// report says how many ways carry each of them.
    @Test
    def testMeasureCountsOneWayTwiceWhenTheRelationCarriesItTwice(): Unit \ Assert =
        let carried = relationWith(
            List#{member("way", "", 1i64), member("way", "shortcut", 1i64)},
            List#{way(1i64, 100.0)}
        );
        Assert.assertTrue(says(measure(carried, 7i64), "lap 100 m over 1 unroled way"));
        Assert.assertTrue(says(measure(carried, 7i64), "roles: (none): 1 way, shortcut: 1 way"))

    @Test
    def testMeasureSaysSoWhenTheAnswerHoldsNoRelation(): Unit \ Assert =
        let asked: Result[String, String] = measure(Nil, 7i64);
        Assert.assertTrue(match asked {
            case Err(problem) => String.contains({substr = "the answer holds no relation 7"}, problem)
            case Ok(_)        => false
        })
}
