/// An answer's text, read: the elements an answer names, the roles its members
/// carry and the line `out geom` gave its ways -- and the three things an answer
/// can be that is not one: an HTML page, a JSON text that stops half way through,
/// and an element that names no id.
///
/// `TestCandidates` hands its readings elements already read; this is the reading
/// that turns a runner's text into them, which is where a runner's own spellings
/// are met.
pub mod TestOverpass {

    use Overpass.{answer, backoff, pace, runners, tries, userAgent}
    use Time.Duration

    /// A fixture spelled with single quotes: a JSON text is written in double ones,
    /// which a Flix string would have to escape at every key.
    def json(text: String): String =
        String.replace(src = "'", dst = "\"", text)

    /// One relation with its members and one way with its line, as `out body` and
    /// `out geom` serve them: the member with no `role` is the role a lap is
    /// chained from, and the node names the line the lap is measured from.
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

    /// The fixture read, or nothing where the reading refused it -- which is what
    /// the counts below are then there to say.
    def read(): List[Overpass.Element] =
        match answer(text()) {
            case Ok(elements) => elements
            case Err(_)       => Nil
        }

    @Test
    def testAnAnswerIsReadIntoItsElements(): Unit \ Assert =
        let elements = read();
        Assert.assertTrue(List.length(elements) == 2);
        Assert.assertTrue(List.get(0, elements)#kind == "relation");
        Assert.assertTrue(List.get(0, elements)#id == 2126739i64);
        Assert.assertTrue(List.get(1, elements)#kind == "way")

    @Test
    def testARelationIsReadWithItsTagsAndItsMembers(): Unit \ Assert =
        let relation = List.get(0, read())#tags;
        Assert.assertTrue(Option.getWithDefault("", Map.get("route", relation)) == "raceway");
        Assert.assertTrue(Option.getWithDefault("", Map.get("distance", relation)) == "13.626");
        Assert.assertTrue(Map.memberOf("motorsport", relation));
        let members = List.get(0, read())#members;
        Assert.assertTrue(List.length(members) == 3);
        Assert.assertTrue(List.get(0, members)#role == "");
        Assert.assertTrue(List.get(2, members)#role == "start-finish");
        Assert.assertTrue(List.get(2, members)#ref == 4i64)

    /// A member carrying no `role` is not a member whose role is unknown: the empty
    /// role is the one the lap is chained from.
    @Test
    def testAMemberNamingNoRoleCarriesTheLapsOwn(): Unit \ Assert =
        Assert.assertTrue(List.get(1, List.get(0, read())#members)#role == "")

    /// The line is what a role's length is measured out of, and an `out body` answer
    /// carries no line at all.
    @Test
    def testAWayIsReadWithTheLineOutGeomGaveIt(): Unit \ Assert =
        let line = List.get(1, read())#line;
        Assert.assertTrue(List.length(line) == 2);
        Assert.assertTrue(List.get(0, line)#lat == 47.9);
        Assert.assertTrue(List.get(1, line)#lon == 0.21);
        Assert.assertTrue(List.isEmpty(List.get(0, read())#line))

    @Test
    def testAnAnswerNamingNoElementsHoldsNothing(): Unit \ Assert =
        match answer(json("{'version': 0.6}")) {
            case Ok(elements) => Assert.assertTrue(List.isEmpty(elements))
            case Err(_)       => Assert.assertTrue(false)
        }

    /// A runner behind a proxy answers a query that timed out with an HTML page and
    /// a status of 200, which is the whole reason a body is looked at and not only
    /// the status that came with it.
    @Test
    def testAnHtmlErrorPageIsNoAnswer(): Unit \ Assert =
        match answer("<html><head><title>504 Gateway Time-out</title></head></html>") {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(String.contains({substr = "not JSON"}, problem))
        }

    @Test
    def testAnAnswerThatStopsHalfWaySaysWhatWasWrong(): Unit \ Assert =
        match answer(json("{'elements': [")) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(String.length(problem) > 0)
        }

    /// An element the answer names without an id is not an element a report can
    /// quote, so the reading refuses the answer rather than printing a relation
    /// whose id is nought.
    @Test
    def testAnElementNamingNoIdIsRefused(): Unit \ Assert =
        match answer(json("{'elements': [{'type': 'relation'}]}")) {
            case Ok(_)        => Assert.assertTrue(false)
            case Err(problem) => Assert.assertTrue(String.contains({substr = "id"}, problem))
        }

    /// The `Https` effect refuses a URL that is not https, so a runner spelled
    /// `http://` fails the walk rather than sending a survey over the open.
    @Test
    def testEveryRunnerIsAskedOverHttps(): Unit \ Assert =
        Assert.assertTrue(List.length(runners()) == 2);
        Assert.assertTrue(List.forAll(each -> String.startsWith({prefix = "https://"}, each), runners()))

    /// What a run asks to be known by, and how it spends its patience: the report
    /// that prints these numbers is the one a reader judges a circuit by.
    @Test
    def testARunNamesItselfAndPacesItself(): Unit \ Assert =
        Assert.assertTrue(String.contains({substr = "elm-motorsport-analysis"}, userAgent()));
        Assert.assertTrue(tries() == 2);
        Assert.assertTrue(Duration.toMillis(pace()) == 1500i64);
        Assert.assertTrue(Duration.toMillis(backoff(1)) == 4000i64);
        Assert.assertTrue(Duration.toMillis(backoff(2)) == 8000i64)
}
