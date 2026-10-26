/// The diff command's own two readings: the arguments it asks with and the drawing it
/// writes. `TestApart` tests the comparison these are printed with, and
/// `TestGeometry` the reading of a file.
pub mod TestDiff {

    use Diff.Args
    use Geometry.Line

    /// A line as a file says it is, with no places drawn: an overlay of two lines of two
    /// places each is written out place by place in `testOverlayDrawsBothLines`, and the
    /// sentences do not need the places at all.
    def kept(name: String, basis: String, source: Option[String]): Line =
        {name = name, props = {basis = basis, source = source, license = Some("ODbL")}, coords = Nil, metres = Nil}

    def asked(args: List[String]): Result[String, Args] =
        Diff.parse(args)

    /// A refusal, and the phrase it refused with.
    def refused(phrase: String, args: List[String]): Bool =
        match asked(args) {
            case Err(problem) => String.contains({substr = phrase}, problem)
            case Ok(_)        => false
        }

    def pathsOf(result: Result[String, Args]): List[String] =
        match result {
            case Ok(ask) => ask#paths
            case Err(_)  => Nil
        }

    def distanceOf(result: Result[String, Args]): Float64 =
        match result {
            case Ok(ask) => ask#every
            case Err(_)  => -1.0
        }

    def overlayOf(result: Result[String, Args]): Option[String] =
        match result {
            case Ok(ask) => ask#svg
            case Err(_)  => None
        }

    @Test
    def testParseWantsExactlyTwoFilesAndFreeChoiceOfTheRest(): Unit \ Assert =
        let both = asked("a.geojson" :: "b.geojson" :: "--every" :: "10" :: "--svg" :: "out.svg" :: Nil);
        // The paths are used as they stand: the report quotes the path the reader typed.
        Assert.assertTrue(
            pathsOf(both) == "a.geojson" :: "b.geojson" :: Nil
        );
        Assert.assertTrue(distanceOf(both) == 10.0);
        Assert.assertTrue(overlayOf(both) == Some("out.svg"));
        Assert.assertTrue(distanceOf(asked("a.geojson" :: "b.geojson" :: Nil)) == 25.0);
        Assert.assertTrue(overlayOf(asked("a.geojson" :: "b.geojson" :: Nil)) == None)

    @Test
    def testParseRefusesWhatItCannotAskWith(): Unit \ Assert =
        Assert.assertTrue(refused("usage: nix run .#geometry -- diff", "a.geojson" :: Nil));
        Assert.assertTrue(refused("usage: nix run .#geometry -- diff", "a.geojson" :: "b.geojson" :: "c.geojson" :: Nil));
        Assert.assertTrue(refused("\"0\" is not a distance", "a.geojson" :: "b.geojson" :: "--every" :: "0" :: Nil));
        // The word the reader typed is the word quoted back, which is what a reader can
        // correct: a coerced number echoes a value they never wrote.
        Assert.assertTrue(refused("\"often\" is not a distance", "a.geojson" :: "b.geojson" :: "--every" :: "often" :: Nil))

    @Test
    def testBaseNameIsTheNameAFileIsQuotedBy(): Unit \ Assert =
        Assert.assertTrue(Diff.baseName("app/static/geometry/le_mans.geojson") == "le_mans");
        Assert.assertTrue(Diff.baseName("/tmp/atlas.geojson") == "atlas");
        // A file written with another extension keeps the name it was given.
        Assert.assertTrue(Diff.baseName("atlas.json") == "atlas.json")

    @Test
    def testQuotedSaysWhatAFileClaimsAboutItself(): Unit \ Assert =
        let surveyed = kept("survey", "osm-centreline", Some("https://www.openstreetmap.org/relation/999"));
        Assert.assertTrue(
            Diff.quoted({name = "survey", props = surveyed#props, coords = Nil, metres = 0.0 :: 5515.0 :: Nil})
                == "survey: basis osm-centreline, 5515.0 m — https://www.openstreetmap.org/relation/999"
        );
        let measured = kept("atlas", "measured-midline", None);
        Assert.assertTrueWithMsg(String.endsWith({suffix = "13630.0 m"}, Diff.quoted({name = "atlas", props = measured#props, coords = Nil, metres = 0.0 :: 13630.0 :: Nil})), "a line with no source says nothing about one, rather than a dash")

    @Test
    def testSaidPrintsOneDirectionOfTheComparison(): Unit \ Assert =
        let lines = kept("survey", "osm-centreline", None) :: kept("atlas", "measured-midline", None) :: Nil;
        let apart: Apart.Apartness = {
            count = 111,
            mean  = 0.6,
            worst = {aMetres = 450.0, bMetres = 450.3, distance = 2.8}
        };
        Assert.assertTrueWithMsg(
            Diff.said(0, lines, apart, 50.0)
                == "sampled every 50 m along survey (111): mean apart 0.6 m, max 2.8 m at 450 m, our-side 450.3 m",
            "the metre along the other line is the reading a report quotes, not the resolution the file was written at"
        )

    @Test
    def testOverlayDrawsBothLinesAndCarriesTheirProvenance(): Unit \ Assert =
        let survey = kept("survey", "osm-centreline", Some("https://www.openstreetmap.org/relation/999"));
        let atlas = kept("atlas", "measured-midline", None);
        let drawing = Diff.overlay(
            survey :: atlas :: Nil,
            ({x = 0.0, y = 0.0} :: {x = 100.0, y = 0.0} :: Nil) :: ({x = 0.0, y = 0.0} :: {x = 100.0, y = 50.0} :: Nil) :: Nil
        );
        Assert.assertTrue(String.startsWith({prefix = "<?xml"}, drawing));
        Assert.assertTrueWithMsg(String.contains({substr = "<path d=\"M 20.0,500.0 L 980.0,500.0\" fill=\"none\" stroke=\"#d43a3a\""}, drawing), "the first line in red, y flipped so north is up");
        Assert.assertTrueWithMsg(String.contains({substr = "stroke=\"#2a6df4\""}, drawing), "the second in blue");
        Assert.assertTrue(
            String.contains({substr = "<!-- survey: osm-centreline — https://www.openstreetmap.org/relation/999 -->"}, drawing)
        );
        Assert.assertTrueWithMsg(String.contains({substr = "<!-- atlas: measured-midline — no source -->"}, drawing), "a line with no source says it has none");
        Assert.assertTrue(String.contains({substr = "Data: survey is © under ODbL."}, drawing));
        Assert.assertTrueWithMsg(String.contains({substr = "height=\"520\""}, drawing), "the margin twice, plus the span of both lines scaled to the fixed width");
        // The drawing ends with a newline, as every kept file does, so an overlay laid
        // twice is one file rather than a file with a byte added to it.
        Assert.assertTrue(String.endsWith({suffix = "</svg>\n"}, drawing))

    @Test
    def testTheCornerOfTheDrawingIsTheFirstPlaceMeasuredAndNotTheZeroOfThePlane(): Unit \ Assert =
        let survey = kept("survey", "osm-centreline", None);
        let places = ({x = 1000.0, y = 1000.0} :: {x = 1200.0, y = 1100.0} :: Nil) :: Nil;
        let drawing = Diff.overlay(survey :: survey :: Nil, places);
        // Framed on the places themselves, the line fills the page rather than sitting
        // in one corner of it.
        Assert.assertTrue(String.contains({substr = "M 20.0,500.0 L 980.0,20.0"}, drawing))
}
