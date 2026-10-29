/// An answer read: the elements it names, the tags a relation carries, the roles its
/// members are under, and the slots its question filled — a way's node refs when the
/// answer was `out body`, a way's line when it was `out geom`.
///
/// `TestOverpass` drives the asking these are handed the text of; `TestCandidates` drives
/// the measurements made of a read answer, and `TestSurvey` the lap chained out of one.
pub mod Overpass.TestAnswer {

    use Overpass.Answer.Element

    /// A fixture spelled with single quotes: a JSON text is written in double ones,
    /// which a Flix string would have to escape at every key.
    def json(text: String): String =
        String.replace(src = "'", dst = "\"", text)

    /// One relation with its members and one way with its line, as `out geom` serves it:
    /// the member with no `role` is the role a lap is chained from, and the node names the
    /// line the lap is measured from.
    def text(): String =
        json(
            "{'version': 0.6, 'generator': 'Overpass API', 'elements': ["
                + " {'type': 'relation', 'id': 2126739,"
                + "  'tags': {'type': 'route', 'route': 'raceway', 'distance': '13.626', 'motorsport': 'endurance'},"
                + "  'members': [ {'type': 'way', 'ref': 1, 'role': ''},"
                + "               {'type': 'way', 'ref': 3},"
                + "               {'type': 'node', 'ref': 4, 'role': 'start-finish'} ]},"
                + " {'type': 'way', 'id': 1, 'geometry': [ {'lat': 47.9, 'lon': 0.2, 'id': 10},"
                + "                                       {'lat': 47.91, 'lon': 0.21} ]} ]}"
        )

    /// The answer read, or nothing where the reading refused it -- which is what
    /// the counts below are then there to say.
    def read_(text: String): List[Element] =
        match Overpass.Answer.read(text) {
            case Ok(reading) => reading#elements
            case Err(_)      => Nil
        }

    def answer_(): List[Element] =
        read_(text())

    @Test
    def testAnAnswerIsReadIntoItsElements(): Unit \ Assert =
        let elements = answer_();
        Assert.assertTrue(List.length(elements) == 2);
        Assert.assertTrue(List.get(0, elements)#kind == "relation");
        Assert.assertTrue(List.get(0, elements)#id == 2126739i64);
        Assert.assertTrue(List.get(1, elements)#kind == "way")

    @Test
    def testARelationIsReadWithItsTagsAndItsMembers(): Unit \ Assert =
        let relation = List.get(0, answer_())#tags;
        Assert.assertTrue(Option.getWithDefault("", Map.get("route", relation)) == "raceway");
        Assert.assertTrue(Option.getWithDefault("", Map.get("distance", relation)) == "13.626");
        Assert.assertTrue(Map.memberOf("motorsport", relation));
        let members = List.get(0, answer_())#members;
        Assert.assertTrue(List.length(members) == 3);
        Assert.assertTrue(List.get(0, members)#role == "");
        Assert.assertTrue(List.get(2, members)#role == "start-finish");
        Assert.assertTrue(List.get(2, members)#ref == 4i64)

    /// A member carrying no `role` is not a member whose role is unknown: the empty
    /// role is the one the lap is chained from.
    @Test
    def testAMemberNamingNoRoleCarriesTheLapsOwn(): Unit \ Assert =
        Assert.assertTrue(List.get(1, List.get(0, answer_())#members)#role == "")

    /// The line is what a role's length is measured out of, and an `out body` answer
    /// carries no line at all.
    @Test
    def testAWayIsReadWithTheLineOutGeomGaveIt(): Unit \ Assert =
        let line = List.get(1, answer_())#line;
        Assert.assertTrue(List.length(line) == 2);
        Assert.assertTrue(List.get(0, line)#lat == 47.9);
        Assert.assertTrue(List.get(1, line)#lon == 0.21);
        Assert.assertTrue(List.isEmpty(List.get(0, answer_())#line))

    /// The stamp the answer carries is the geometry's own claim about when the map was
    /// surveyed, and nothing else's.
    @Test
    def testAnAnswerCarriesTheMomentTheMapWasSurveyed(): Unit \ Assert =
        match Overpass.Answer.read(json("{'elements': [], 'osm3s': {'timestamp_osm_base': '2026-04-01T10:00:00Z'}}")) {
            case Ok(reading) => Assert.assertTrue(reading#surveyedAt == Some("2026-04-01T10:00:00Z"))
            case Err(problem) => Assert.assertTrueWithMsg(false, "read the answer: ${problem}")
        }

    /// One shape answers both questions, and the question decides the slots: what the
    /// survey asks carries a node's degrees and a way's node refs and no line, which is
    /// what a lap is chained out of.
    @Test
    def testTheBodySpellingFillsTheSlotsAChainWalks(): Unit \ Assert =
        let asked = json(
            "{'elements': ["
                + " {'type': 'node', 'id': 10, 'lat': 47.9, 'lon': 0.2},"
                + " {'type': 'way', 'id': 1, 'nodes': [10, 11, 12]} ]}"
        );
        let elements = read_(asked);
        let node = List.get(0, elements);
        let way = List.get(1, elements);
        Assert.assertTrue(Option.map(at -> at#lat, node#at) == Some(47.9));
        Assert.assertTrue(List.isEmpty(node#line));
        Assert.assertTrue(way#nodes == 10i64 :: 11i64 :: 12i64 :: Nil);
        Assert.assertTrue(List.isEmpty(way#line))

    @Test
    def testAnAnswerNamingNoElementsHoldsNothing(): Unit \ Assert =
        match Overpass.Answer.read(json("{'version': 0.6}")) {
            case Ok(reading) => Assert.assertTrue(List.isEmpty(reading#elements))
            case Err(_)      => Assert.assertTrue(false)
        }

    /// A runner behind a proxy answers a query that timed out with an HTML page and
    /// a status of 200. The status is `Overpass.kept`'s to refuse; an answer that is
    /// no JSON at all is refused here too, so a text read straight from a file is met
    /// the same way.
    @Test
    def testAnHtmlErrorPageIsNoAnswer(): Unit \ Assert =
        match Overpass.Answer.read("<html><head><title>504 Gateway Time-out</title></head></html>") {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(String.length(problem) > 0)
        }

    /// An answer that stops half-way, or names an element with no id to quote, is
    /// refused rather than read short: a report printing a relation whose id is nought
    /// is worse than one that says what was wrong.
    @Test
    def testAnAnswerThatStopsHalfWaySaysWhatWasWrong(): Unit \ Assert =
        match Overpass.Answer.read(json("{'elements': [")) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(String.length(problem) > 0)
        };
        match Overpass.Answer.read(json("{'elements': [{'type': 'relation'}]}")) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(String.contains({substr = "id"}, problem))
        }

    /// A node carrying one of the two degrees and not the other is no place, which the
    /// chain would otherwise read as a lap with a place missing.
    @Test
    def testANodeWithOneDegreeAndNotTheOtherIsRefused(): Unit \ Assert =
        match Overpass.Answer.read(json("{'elements': [ {'type': 'node', 'id': 10, 'lat': 47.9} ]}")) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(String.contains({substr = "lat"}, problem))
        }

    /// An id is not a distance that may be rounded: a node ref with a fraction names
    /// no element, and cutting it to a whole would chain the lap onto whatever way
    /// wore the whole part of the number. A whole spelled with a decimal point is
    /// still the whole it spells.
    @Test
    def testAFractionalRefIsRefusedAndNotCut(): Unit \ Assert =
        match Overpass.Answer.read(json("{'elements': [ {'type': 'way', 'id': 1, 'nodes': [10, 10.5]} ]}")) {
            case Ok(_)        => Assert.assertTrueWithMsg(false, "read a way whose node ref was a fraction")
            case Err(problem) => Assert.assertTrue(String.contains({substr = "fraction"}, problem))
        };
        match Overpass.Answer.read(json("{'elements': [ {'type': 'way', 'id': 1, 'nodes': [10, 11.0]} ]}")) {
            case Ok(reading) =>
                Assert.assertTrue(List.get(0, reading#elements)#nodes == 10i64 :: 11i64 :: Nil)
            case Err(problem) =>
                Assert.assertTrueWithMsg(false, "refused a whole spelled with a decimal point: ${problem}")
        }
}
