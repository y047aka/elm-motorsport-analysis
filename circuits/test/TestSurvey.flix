/// The survey between an Overpass answer and a geometry file: the lap chained out of a
/// relation's ways, the line stretched to the length the circuit publishes
/// and thinned to what a drawing can show. `nix run .#geometry -- survey` holds the whole of
/// it to the bytes the app serves, over both kept answers.
///
/// The answer these are handed is `Overpass.Answer`'s reading of one, so the fixture below
/// spells an `out body` answer and checks the slots the chain walks.
///
/// The word's own arguments — which circuit, which answer, whether a file is laid down — are
/// read here as well; those bytes, spelled and laid out, are `Geometry.TestWrite`'s, and the
/// sphere, the projection and the tenth they are measured in are `TestGeodesy`'s.
pub mod TestSurvey {

    use Circuit.Circuit
    use Geodesy.Place
    use Geodesy.Point

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
                match Overpass.Answer.read(text) {
                    case Err(problem) => Err(problem)
                    case Ok(reading) => Result.map(geometry -> Geometry.Write.file(circuit, geometry), Survey.lapOf(reading, circuit))
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
        match Overpass.Answer.read(square(2126739)) {
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
        Assert.assertTrue(refusedIt(Overpass.Answer.read("<html>the gate is closed</html>")))

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

    /// The `within` a circuit authors narrows the distance its node is held to, and one
    /// that names none leaves the ten metres every node is held to. COTA authors its
    /// crosshair at the same ten the fallback is, so one fixture read both ways is what
    /// tells the two readings apart. Flix leaves no way to say one field of a record
    /// differently, so each reading below spells every field COTA's says and differs
    /// only in the crosshair under test.
    @Test
    def testThePublishedLineNarrowsItsOwnCrosshairAndNamesNoneToTen(): Unit \ Assert =
        let asking = answer(List.append(relation(6537729, member("node", "finish", 1) :: Nil) :: Nil, places()));
        match Circuit.byWord("cota") {
            case None => Assert.assertTrue(false)
            case Some(cota) =>
                let place = Option.getWithDefault({lat = 0.0, lon = 0.0}, Option.map(line -> line#place, cota#timingLine));
                let narrowed = {
                    relation = cota#relation,
                    word = cota#word,
                    timedFrom = cota#timedFrom,
                    timingLine = Some({place = place, within = Some(5.0)}),
                    lap = cota#lap,
                    sectors = cota#sectors,
                    file = cota#file,
                    atlas = cota#atlas,
                    survey = cota#survey
                };
                let unauthored = {
                    relation = narrowed#relation,
                    word = narrowed#word,
                    timedFrom = narrowed#timedFrom,
                    timingLine = Some({place = place, within = None}),
                    lap = narrowed#lap,
                    sectors = narrowed#sectors,
                    file = narrowed#file,
                    atlas = narrowed#atlas,
                    survey = narrowed#survey
                };
                match Overpass.Answer.read(asking) {
                    case Err(problem) => Assert.assertTrueWithMsg(false, "read the answer: ${problem}")
                    case Ok(reading) =>
                        // Authored: the distance the circuit names is the distance kept.
                        Assert.assertTrue(refused("which is not within 5 m", Survey.lapOf(reading, narrowed)));
                        // Named none: the ten metres every node is held to, quoted in
                        // the refusal and not the authored figure it leaves behind.
                        Assert.assertTrue(refused("which is not within 10 m", Survey.lapOf(reading, unauthored)))
                }
        }

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
    def testDirectionIsWhichWayTheSurveyRuns(): Unit \ Assert =
        // East, then south, then west, then north is clockwise on a drawing whose `y` runs
        // south; the same points in the other order are the race run backwards.
        let forth = line((0.0, 0.0) :: (100.0, 0.0) :: (100.0, 100.0) :: (0.0, 100.0) :: Nil);
        Assert.assertTrue(Survey.turnDirection(forth) == Survey.clockwise());
        Assert.assertTrue(Survey.turnDirection(List.reverse(forth)) == Survey.counterClockwise())

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
    // --------------------------------------------------------------- the survey word

    @Test
    def testParseWantsACircuitAndTakesTheAnswerWhereTheCircuitKeepsIt(): Unit \ Assert =
        match Survey.parse("cota" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#circuit#word == "cota");
                Assert.assertTrue(asked#answer == "circuits/cota/overpass.json");
                // The answer taken from the circuit's directory is not one the reader asked
                // for, which is what tells a circuit nobody has surveyed from a file that
                // cannot be read.
                Assert.assertTrue(not asked#asked);
                // The default run reaches no network: it reads the kept answer.
                Assert.assertTrue(not asked#fetch);
                Assert.assertTrue(not asked#write)
        }

    @Test
    def testParseRefusesWhatItCannotSurvey(): Unit \ Assert =
        Assert.assertTrue(argumentRefused("survey reads one circuit", Survey.parse(Nil)));
        Assert.assertTrue(argumentRefused("no circuit is surveyed under 'monza': known are cota, le_mans", Survey.parse("monza" :: Nil)));
        Assert.assertTrue(argumentRefused("option '--answer' requires an argument", Survey.parse("--answer" :: Nil)));
        // A flag is no file: `--answer --write` is a reader who meant something else, and
        // the survey that read it as a path would report a file that cannot be opened.
        Assert.assertTrue(argumentRefused("--answer names no file to read", Survey.parse("cota" :: "--answer" :: "--write" :: Nil)));
        Assert.assertTrue(argumentRefused("unrecognized option '--froze'", Survey.parse("cota" :: "--froze" :: Nil)))

    @Test
    def testParseTakesAnAnswerNamedElsewhereAndLaysTheFileDown(): Unit \ Assert =
        match Survey.parse("le_mans" :: "--answer" :: "elsewhere/answer.json" :: "--write" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#answer == "elsewhere/answer.json");
                // A named answer is one the reader asked for: if it cannot be read, that is
                // the failure, and not a circuit nobody has surveyed yet.
                Assert.assertTrue(asked#asked);
                Assert.assertTrue(asked#write)
        }

    /// `--fetch` is the network raised as a flag rather than a command word: the run
    /// keeps its answer where `--answer` points — the circuit's own directory when it
    /// names none — and lays the geometry down only when `--write` says so.
    @Test
    def testFetchRaisesTheNetworkAndKeepsWhereTheAnswerPoints(): Unit \ Assert =
        match Survey.parse("cota" :: "--fetch" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#circuit#word == "cota");
                Assert.assertTrue(asked#fetch);
                // A `--fetch` without `--write` keeps the evidence and answers whether
                // the fresh survey moves the served bytes, laying nothing down.
                Assert.assertTrue(not asked#write);
                Assert.assertTrue(asked#answer == "circuits/cota/overpass.json")
        };
        match Survey.parse("cota" :: "--fetch" :: "--answer" :: "elsewhere.json" :: "--write" :: Nil) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "parsed: ${problem}")
            case Ok(asked) =>
                Assert.assertTrue(asked#answer == "elsewhere.json");
                Assert.assertTrue(asked#fetch);
                Assert.assertTrue(asked#write)
        }

    // ----------------------------------------------------------------------- the parting

    @Test
    def testFirstPartSaysWhereTwoFilesPart(): Unit \ Assert =
        // The reading of a drift is where the bytes part and what each side says there, not
        // the whole file.
        Assert.assertTrue(Survey.firstPart("one\ntwo\n", "one\ntwo\n") == "the two files are the same bytes after all");
        Assert.assertTrue(Survey.firstPart("one\ntwo\n", "one\nthree\n") == "line 2 is \"three\" in the file, \"two\" from the answer");
        Assert.assertTrue(
            Survey.firstPart("one\ntwo\nthree\n", "one\n") == "the files part at line 2, where one of them has nothing left"
        )

    @Test
    def testAPartingQuotesALineOnlyAsFarAsItIsWorthReading(): Unit \ Assert =
        // Two of a geometry's lines are thousands of numbers long; a metre that moved is
        // found by where it moved, not by the eleven thousand digits around it.
        let long = String.repeat(400, "1234");
        let part = Survey.firstPart("${long}\n", "1234\n");
        Assert.assertTrue(String.startsWith({prefix = "line 1 is \"1234\" in the file, \"12341234"}, part));
        Assert.assertTrue(String.endsWith({suffix = "\" from the answer"}, part));
        Assert.assertTrue(String.length(part) < 300)

    /// A refusal that says what the reader asked for, which is the only thing a command can
    /// say to someone at a terminal.
    def argumentRefused(problem: String, asked: Result[Cli.Args.ArgsError, Survey.Args]): Bool =
        match asked {
            case Err(one) => String.contains({substr = problem}, "${one}")
            case Ok(_)    => false
        }
}
