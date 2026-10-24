/// The survey between an Overpass answer and a geometry file: the answer read, the lap
/// chained out of a relation's ways, the line stretched to the length the circuit
/// publishes and thinned to what a drawing can show. These are the readings
/// `circuits/tests/circuit-geometry.test.ts` holds the TypeScript pipeline to, in the
/// language the commands a person runs are written in — the same readings twice because
/// two writers lay one file until the pipeline moves, and a lap that chains one way in one
/// of them and another way in the other is a field drawn at the wrong metre for everyone.
pub mod TestSurvey {

    use Apart.Point
    use Circuit.Circuit
    use Geometry.Place

    // ------------------------------------------------------------------ the fixtures

    /// A node of an answer, at the degrees OpenStreetMap surveyed for it.
    def node(id: Int32, lat: Float64, lon: Float64): String =
        "{\"type\":\"node\",\"id\":${id},\"lat\":${lat},\"lon\":${lon}}"

    /// A way of an answer. The one tag a chain reads is `oneway`, which is the only
    /// permission a chain has to turn a way around.
    def way(id: Int32, oneway: Bool, ids: List[Int32]): String =
        let driven = if (oneway) "yes" else "no";
        "{\"type\":\"way\",\"id\":${id},\"tags\":{\"oneway\":\"${driven}\"},\"nodes\":${numbers(ids)}}"

    /// A relation: its members, in the order the survey walks them, which is no order at
    /// all — a lap has to be chained out of them rather than read off them.
    def relation(id: Int32, members: List[String]): String =
        "{\"type\":\"relation\",\"id\":${id},\"tags\":{\"name\":\"a circuit\"},\"members\":${spells(members)}}"

    def member(kind: String, role: String, ref: Int32): String =
        "{\"type\":\"${kind}\",\"role\":\"${role}\",\"ref\":${ref}}"

    /// An answer of these elements, stamped with when the map it surveyed was surveyed.
    def answer(elements: List[String]): String =
        "{\"version\":0.6,\"elements\":${spells(elements)},\"osm3s\":{\"timestamp_osm_base\":\"2026-04-01T10:00:00Z\"}}"

    def spells(words: List[String]): String =
        "[${String.intercalate(",", words)}]"

    def numbers(ids: List[Int32]): String =
        "[${String.intercalate(",", List.map(id -> "${id}", ids))}]"

    /// Six places: the four corners of a lap, and two beyond it that a pit lane runs
    /// between. The lap runs east, then south, then west, then home — clockwise on a
    /// drawing whose `y` runs south, which is the direction a survey is asked to say for
    /// itself.
    def places(): List[String] =
        node(1, 30.0, -97.6) :: node(2, 30.0, -97.59) :: node(3, 29.99, -97.59) :: node(4, 29.99, -97.6) :: node(
            5,
            30.05,
            -97.55
        ) :: node(6, 30.05, -97.54) :: Nil

    def lapWays(): List[String] =
        way(10, true, 1 :: 2 :: Nil)
            :: way(11, false, 2 :: 3 :: Nil)
            :: way(12, false, 3 :: 4 :: Nil)
            :: way(13, false, 4 :: 1 :: Nil)
            :: Nil

    def pitWays(): List[String] =
        way(20, false, 5 :: 6 :: Nil) :: Nil

    /// The members of a relation that holds the whole circuit: the line the lap is timed
    /// from, the ways the lap is chained from and the ways the pit lane is drawn from.
    def members(): List[String] =
        member("node", "start-finish", 1)
            :: member("way", "", 10)
            :: member("way", "", 11)
            :: member("way", "", 12)
            :: member("way", "", 13)
            :: member("way", "pit_lane", 20)
            :: Nil

    /// The answer of the square circuit, as the relation named.
    def square(id: Int32): String =
        answer(relation(id, members()) :: List.append(places(), List.append(lapWays(), pitWays())))

    /// An answer read, chained and written: the bytes the file would carry, or the sentence
    /// that refuses it.
    def written(word: String, text: String): Result[String, String] =
        match Circuit.byWord(word) {
            case None => Err("the test names no circuit")
            case Some(circuit) =>
                match Survey.answer(text) {
                    case Err(problem) => Err(problem)
                    case Ok(reading) => Result.map(geometry -> Write.geoJson(circuit, geometry), Survey.lapOf(reading, circuit))
                }
        }

    def refused(phrase: String, read: Result[String, a]): Bool =
        match read {
            case Err(problem) => String.contains({substr = phrase}, problem)
            case Ok(_)        => false
        }

    /// The file the survey wrote says this, or the survey refused to write one at all —
    /// which is a failure of a different kind, and says so.
    def says(phrase: String, read: Result[String, String]): Unit \ Assert =
        match read {
            case Ok(text) => Assert.assertTrue(String.contains({substr = phrase}, text))
            case Err(problem) => Assert.assertTrueWithMsg(false, "the survey refused: ${problem}")
        }

    def refusedIt(read: Result[String, a]): Bool =
        match read {
            case Err(_) => true
            case Ok(_)  => false
        }

    // -------------------------------------------------------------------- the answer

    @Test
    def testAnswerReadsThePlacesTheWaysRunThrough(): Unit \ Assert =
        match Survey.answer(square(2126739)) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "read the answer: ${problem}")
            case Ok(reading) =>
                // The stamp the answer carries is the geometry's own claim about when the
                // map was surveyed, and nothing else's.
                Assert.assertTrue(reading#surveyedAt == Some("2026-04-01T10:00:00Z"));
                // One relation, six nodes and five ways.
                Assert.assertTrue(List.length(reading#elements) == 12);
                let nodes = List.filter(each -> each#kind == "node", reading#elements);
                let ways = List.filter(each -> each#kind == "way", reading#elements);
                Assert.assertTrue(List.length(nodes) == 6);
                Assert.assertTrue(List.length(ways) == 5);
                // A node carries a place and no line; a way the ids of its line and no
                // place of its own.
                Assert.assertTrue(Option.map(at -> at#lon, Option.flatMap(each -> each#at, List.head(nodes))) == Some(-97.6));
                Assert.assertTrue(List.isEmpty(List.flatMap(each -> each#nodes, nodes)));
                Assert.assertTrue(Option.map(each -> List.length(each#members), List.head(reading#elements)) == Some(6))
        }

    @Test
    def testAnswerRefusesTextThatIsNoAnswer(): Unit \ Assert =
        // What is no JSON at all failed to answer, and the parser's own words are the only
        // thing a run knows about it.
        Assert.assertTrue(refusedIt(Survey.answer("<html>the gate is closed</html>")))

    @Test
    def testSurveyRefusesAnAnswerAboutAnotherRelation(): Unit \ Assert =
        // The relation is what the survey is read out of; an answer that holds another one
        // is an answer about another place, and the refusal says which one was asked for.
        Assert.assertTrue(refused("the answer holds no relation 2126739", written("le_mans", square(424242))))

    @Test
    def testSurveyRefusesAQuestionTheRelationCannotAnswer(): Unit \ Assert =
        // Every metre is measured from whichever relation member was answered to, so a
        // circuit asking for a line the relation tags no member for is a circuit and a
        // survey that have nothing to do with each other. COTA asks for `finish`; this
        // answer tags its line `start-finish`.
        Assert.assertTrue(
            refused(
                "relation 6537729 tags no member with role 'finish'",
                written("cota", square(6537729))
            )
        )

    @Test
    def testSurveyRefusesALineThatDoesNotStandWhereTheCircuitPutsIt(): Unit \ Assert =
        // COTA puts its `finish` line at a published place, and the relation's node has to
        // stand within the map's own crosshair of it. The refusal lists the lines the
        // relation does tag and how far each stands from the published place, which is the
        // reading the reader needed in the first place.
        let asking = answer(List.append(relation(6537729, member("node", "finish", 1) :: Nil) :: Nil, places()));
        Assert.assertTrue(refused("which is not within 10 m", written("cota", asking)));
        Assert.assertTrue(refused("The relation's lines: role=finish is", written("cota", asking)))

    // -------------------------------------------------------------------- the chain

    /// One way of a relation as a chain sees it. The ids are the answer's, which an answer
    /// spells as far bigger numbers than these; only the fixture's are small.
    def part(id: Int32, oneway: Bool, ids: List[Int32]): Survey.Segment = {
        id = Int32.toInt64(id),
        nodes = List.map(Int32.toInt64, ids),
        oneway = oneway
    }

    def at(held: Map[Int64, Place], id: Int32, lat: Float64, lon: Float64): Map[Int64, Place] =
        Map.insert(Int32.toInt64(id), {lat = lat, lon = lon}, held)

    def corners(): Map[Int64, Place] =
        at(at(at(at(Map.empty(), 1, 30.0, -97.6), 2, 30.0, -97.59), 3, 29.99, -97.59), 4, 29.99, -97.6)

    @Test
    def testChainTurnsAWayThatIsNotDrivenOneWay(): Unit \ Assert =
        // The way the lap starts from has to be driven the way the race goes round; after
        // it a way may be taken backwards, which is what closes a lap out of ways each
        // mapper drew in whichever direction they happened to walk.
        let chained = Survey.chain(
            part(10, true, 1 :: 2 :: Nil) :: part(11, false, 4 :: 3 :: Nil) :: part(12, false, 3 :: 2 :: Nil) :: part(13, false, 4 :: 1 :: Nil) :: Nil,
            corners(),
            Some(1i64)
        );
        match chained {
            case Err(problem) => Assert.assertTrueWithMsg(false, "chained: ${problem}")
            // Turned to start at the line the lap is measured from, and closed back onto
            // it: the first place is the last one again.
            case Ok(ids) => Assert.assertTrue(ids == 1i64 :: 2i64 :: 3i64 :: 4i64 :: 1i64 :: Nil)
        }

    @Test
    def testChainRefusesAWayItCouldNotTake(): Unit \ Assert =
        // A way the chain never reached is a survey read wrongly, and is reported with the
        // two figures that decide its remedy: how long it is, and how far its nearest end
        // stands from where the chain stopped.
        let chained = Survey.chain(
            part(10, true, 1 :: 2 :: Nil) :: part(11, false, 2 :: 3 :: Nil) :: part(99, true, 7 :: 8 :: Nil) :: Nil,
            at(at(corners(), 7, 29.9, -97.9), 8, 29.9, -97.89),
            Some(1i64)
        );
        Assert.assertTrue(refused("ways left out of the chain: 99 is", chained));
        Assert.assertTrue(refused("where the chain stopped, oneway", chained))

    @Test
    def testChainRefusesALapThatDoesNotComeBack(): Unit \ Assert =
        // The lap closed is what every metre on it is measured from; three sides of a
        // square stop somewhere else than they started, and say how far away.
        let chained = Survey.chain(
            part(10, true, 1 :: 2 :: Nil) :: part(11, false, 2 :: 3 :: Nil) :: Nil,
            corners(),
            Some(1i64)
        );
        Assert.assertTrue(refused("the lap does not close: its last point stands", chained))

    @Test
    def testChainRefusesAStartNoWayCarries(): Unit \ Assert =
        let chained = Survey.chain(part(10, true, 2 :: 3 :: Nil) :: Nil, corners(), Some(1i64));
        Assert.assertTrue(refused("the relation holds no way the lap can start from", chained))

    @Test
    def testChainOpensALineWithNothingToTimeFromWhereNoOtherEnds(): Unit \ Assert =
        // A pit lane has no line to start at, so it opens with the way no other way runs
        // into, and is expected to close back onto nothing.
        let chained = Survey.chain(
            part(20, false, 5 :: 6 :: Nil) :: part(21, false, 6 :: 7 :: Nil) :: Nil,
            at(corners(), 5, 30.05, -97.55),
            None
        );
        match chained {
            case Err(problem) => Assert.assertTrueWithMsg(false, "chained: ${problem}")
            case Ok(ids)      => Assert.assertTrue(ids == 5i64 :: 6i64 :: 7i64 :: Nil)
        }

    // ------------------------------------------------------------------- the thinning

    def point(pair: (Float64, Float64)): Point =
        match pair {
            case (x, y) => {x = x, y = y}
        }

    def line(points: List[(Float64, Float64)]): List[Point] = List.map(point, points)

    @Test
    def testSimplifyThinsALineToWhatADrawingCannotShow(): Unit \ Assert =
        // A side that runs straight keeps its two ends and nothing between them; a bend of
        // half a metre is a bend no drawing measured at a metre can see, and a bend of
        // twenty metres is a corner that stays.
        let straight = line((0.0, 0.0) :: (25.0, 0.0) :: (50.0, 0.0) :: (75.0, 0.0) :: (100.0, 0.0) :: Nil);
        Assert.assertTrue(Survey.simplify(straight, 0, 4) == 0 :: 4 :: Nil);
        let shallow = line((0.0, 0.0) :: (50.0, 0.5) :: (100.0, 0.0) :: Nil);
        Assert.assertTrue(Survey.simplify(shallow, 0, 2) == 0 :: 2 :: Nil);
        let corner = line((0.0, 0.0) :: (50.0, 20.0) :: (100.0, 0.0) :: Nil);
        Assert.assertTrue(Survey.simplify(corner, 0, 2) == 0 :: 1 :: 2 :: Nil)

    @Test
    def testSimplifyTurnsOnTheFirstOfTwoEquallyFarPoints(): Unit \ Assert =
        // Two bends equally far from the line joining the ends: the first is the one turned
        // on, which is what makes two runs over one answer keep the same points.
        let twin = line((0.0, 0.0) :: (25.0, 20.0) :: (50.0, 0.0) :: (75.0, 20.0) :: (100.0, 0.0) :: Nil);
        Assert.assertTrue(Survey.simplify(twin, 0, 4) == 0 :: 1 :: 2 :: 3 :: 4 :: Nil)

    @Test
    def testSimplifyOfALineOfOnePointHoldsItTwice(): Unit \ Assert =
        // The two ends of a line of one point are the same point, and a line joined to
        // another at its end holds that point once: the ends are written before anything is
        // measured between them.
        Assert.assertTrue(Survey.simplify(line((0.0, 0.0) :: Nil), 0, 0) == 0 :: 0 :: Nil)

    @Test
    def testCumulativeRunsALineFromItsOwnZero(): Unit \ Assert =
        let metres = Survey.cumulative(line((0.0, 0.0) :: (3.0, 4.0) :: (3.0, 4.0) :: Nil));
        // Each stretch is its own hypotenuse, the sum runs forwards, and a stretch of no
        // length adds nothing rather than a NaN.
        Assert.assertTrue(metres == 0.0 :: 5.0 :: 5.0 :: Nil)

    @Test
    def testDirectionIsWhichWayTheSurveyRuns(): Unit \ Assert =
        // East, then south, then west, then north is clockwise on a drawing whose `y` runs
        // south; the same points in the other order are the race run backwards.
        let forth = line((0.0, 0.0) :: (100.0, 0.0) :: (100.0, 100.0) :: (0.0, 100.0) :: Nil);
        Assert.assertTrue(Survey.turnDirection(forth) == Survey.clockwise());
        Assert.assertTrue(Survey.turnDirection(List.reverse(forth)) == Survey.counterClockwise())

    @Test
    def testTenthsRoundUpAndHoldTheSurvey(): Unit \ Assert =
        // The tenth is what every baseline was rendered at, and half goes up.
        Assert.assertTrue(Survey.roundTenth(172.8) == 172.8);
        Assert.assertTrue(Write.number(Survey.roundTenth(1.05)) == "1.1");
        Assert.assertTrue(Write.number(Survey.roundTenth(1728.0)) == "1728");
        Assert.assertTrue(Write.number(Survey.roundTenth(0.0)) == "0")

    // -------------------------------------------------------------------- the metres

    @Test
    def testOneDegreeOfLatitudeIsTheSphereMetres(): Unit \ Assert =
        // 6371008.8 m of sphere, and the drawing's own Geodesy re-runs the same two
        // factors, so a degree of latitude is the same 111195.1 m here and there — the
        // figure does not turn on which parallel it was measured at.
        let degree = Survey.apart({lat = 30.0, lon = -97.6}, {lat = 31.0, lon = -97.6});
        Assert.assertTrue(Write.number(Survey.roundTenth(degree)) == "111195.1")

    @Test
    def testEastWestIsTakenAtTheParallelOfThePlaceAhead(): Unit \ Assert =
        // A degree of longitude is shorter the further from the equator one goes: the same
        // degree stands 111195.1 m apart on the equator and 96297.8 m apart at 30°, taken at
        // the parallel of the place ahead — the one approximation asked of distances across
        // a circuit's few kilometres.
        let equator = Survey.apart({lat = 0.0, lon = 0.0}, {lat = 0.0, lon = 1.0});
        let north = Survey.apart({lat = 30.0, lon = 0.0}, {lat = 30.0, lon = 1.0});
        Assert.assertTrue(north < equator);
        Assert.assertTrue(Write.number(Survey.roundTenth(equator)) == "111195.1");
        Assert.assertTrue(Write.number(Survey.roundTenth(north)) == "96297.8")

    @Test
    def testPolylineMetresWalkTheStretchesInOrder(): Unit \ Assert =
        let walked = Survey.polylineMetres({lat = 0.0, lon = 0.0} :: {lat = 0.0, lon = 1.0} :: {lat = 0.0, lon = 2.0} :: Nil);
        Assert.assertTrue(Write.number(Survey.roundTenth(walked)) == "222390.2")

    @Test
    def testTheCornerIsTheNorthWestOfEveryPlace(): Unit \ Assert =
        // The drawing's metres are measured from this corner, so no line of the drawing
        // falls below its own zero.
        let corner = Survey.cornerOf({lat = 30.0, lon = -97.6} :: {lat = 30.2, lon = -97.4} :: {lat = 29.9, lon = -97.9} :: Nil);
        Assert.assertTrue(corner#lat == 30.2);
        Assert.assertTrue(corner#lon == -97.9)

    // ------------------------------------------------------------- the survey end to end

    @Test
    def testTheSquareIsStretchedToTheLengthTheCircuitPublishes(): Unit \ Assert =
        // The survey measures about 1100 m of OpenStreetMap and the circuit publishes
        // 13625.7 m; every metre on the line is the surveyed metre times one factor, which
        // is what ends the lap at the published figure rather than near it.
        let file = written("le_mans", square(2126739));
        says("\"lap_length_m\": 13625.7", file);
        says(",13625.7]", file);
        // The direction the chained survey runs, which is which way a car goes round the
        // drawing.
        says("\"direction\": \"clockwise\"", file);
        // The frame the degrees project through: its origin the north-west corner of every
        // place of both lines, pit lane included.
        says("\"frame\": {\"origin\":{\"lat\":30.05,\"lon\":-97.6}", file)

    @Test
    def testThePitLaneIsDrawnAndNotTimed(): Unit \ Assert =
        let file = written("le_mans", square(2126739));
        // The whole feature, byte for byte: a line with no metres, because nothing times
        // along it, and nothing claimed beside what every centreline claims of itself.
        says(pitFeature(), file);
        // The survey's own length is written as the double it summed to, since that is the
        // figure every metre on the line was multiplied by.
        says("\"surveyed_length_m\"", file)

    /// The pit lane as the file writes it: the degrees it was surveyed at, and four
    /// properties. A fifth would be a claim about a pit lane that nothing measured.
    def pitFeature(): String =
        "    {"
            + "\n      \"type\": \"Feature\","
            + "\n      \"properties\": {"
            + "\n        \"role\": \"pit_lane\","
            + "\n        \"circuit\": \"le_mans\","
            + "\n        \"basis\": \"osm-centreline\","
            + "\n        \"license\": \"ODbL\""
            + "\n      },"
            + "\n      \"geometry\": {\"type\":\"LineString\",\"coordinates\":[[-97.55,30.05],[-97.54,30.05]]}"
            + "\n    }"
}
