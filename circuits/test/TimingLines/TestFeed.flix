/// The feed readings on a CSV small enough to write out here: what counts as a
/// time, how a class's fastest is pooled, what the shares place where round the
/// lap, and how two seasons' placements are laid against each other. The report
/// that prints them, and the arguments it is given, are `Cli.TestTimingLines`'s.
pub mod TimingLines.TestFeed {

    use Cli.Errors.CliError
    use TimingLines.Feed.{
        CircuitMap, Column, Fastest, Line, Placement, Row, Times, count,
        decode, fastestSectors, metres, movedMetres, movement, percent, placesOf,
        publishedLines, seconds, sectorsOf, sharesOf, speeds, table, whole
    }
    use Util.Duration.Duration

    /// Two classes, one lap of each that recorded nought in a sector, and one lap
    /// that recorded nothing in two of them.
    def feed(): String =
        List.join("\n", List#{
            "CLASS;S1;S2;S3",
            "Hypercar;60.000;70.000;80.000",
            "Hypercar;59.000;0.000;85.000",
            "LMGT3;40.000;50.000;60.000",
            "LMGT3;;;0.000"
        })

    /// A circuit whose map puts its first line 2000 m round the lap and its second
    /// 1500 m further on, and whose lap is the 5515 m COTA publishes.
    def circuitMap(): CircuitMap =
        { lapLength = 5515.0, lines = line("s2", 2000.0) :: line("s3", 3500.0) :: Nil }

    def line(id: String, at: Float64): Line =
        { id = id, metres = at }

    def times(s1: Int32, s2: Int32, s3: Int32): Times =
        {
            s1 = Duration.fromMillis(s1),
            s2 = Duration.fromMillis(s2),
            s3 = Duration.fromMillis(s3)
        }

    def placed(name: String, at: List[Float64]): Placement =
        { carClass = name, positions = at }

    /// The three sectors of one reading, in milliseconds. A record carries no `Eq`,
    /// so a test compares the numbers one holds rather than the record.
    def millis(each: Fastest): List[Int32] =
        List.map(Util.Duration.millis, sectorsOf(each#times))

    def of(name: String, fastest: List[Fastest]): Option[List[Int32]] =
        Option.map(millis, List.find(each -> each#carClass == name, fastest))

    def ran(name: String, fastest: List[Fastest]): Option[Fastest] =
        List.find(each -> each#carClass == name, fastest)

    def total(shares: List[Float64]): Float64 =
        List.foldLeft((acc, x) -> acc + x, 0.0, shares)

    def complains(phrase: String, result: Result[CliError, a]): Bool =
        match result {
            case Err(e) => String.contains({substr = phrase}, "${e}")
            case Ok(_)  => false
        }

    def closeTo(expected: Float64, actual: Float64): Bool =
        Float64.abs(expected - actual) < 0.000001f64

    /// A feed's rows, or none. A fixture that fails to read makes the test using it
    /// fail by name, which is the message a test cannot print.
    def rowsOf(text: String): List[Row] =
        match decode("x.csv", text) {
            case Ok(rows) => rows
            case Err(_)   => Nil
        }

    /// A sector time as the feed's own reading of it leaves it, in milliseconds, and
    /// -1 for a cell that is no time at all.
    def millisOf(cell: String): Int32 =
        match rowsOf("CLASS;S1;S2;S3\nHypercar;${cell};1.000;2.000") |> fastestSectors {
            case Ok(each) => Option.getWithDefault(-1, Option.map(ran -> List.get(0, ran), of("Hypercar", each)))
            case Err(_)   => -1
        }

    // ---------------------------------------------------------------- the feed

    @Test
    def testOneRowPerLap(): Unit \ Assert =
        match decode("x.csv", feed()) {
            case Ok(rows) => Assert.assertTrue(List.length(rows) == 4)
            case Err(_)   => Assert.assertTrue(false)
        }

    /// The timing files lead with a byte-order mark, and the first column is read
    /// by its name.
    @Test
    def testByteOrderMarkIsStripped(): Unit \ Assert =
        match decode("x.csv", "\uFEFF${feed()}\n") {
            case Ok(rows) =>
                Assert.assertTrue(List.length(rows) == 4);
                Assert.assertTrue(List.get(0, rows)#carClass == "Hypercar")
            case Err(_) => Assert.assertTrue(false)
        }

    /// A row whose cell count disagrees with the header's is a corrupt feed, not a
    /// row to guess at.
    @Test
    def testTornLineIsRefused(): Unit \ Assert =
        Assert.assertTrue(complains("x.csv", decode("x.csv", "CLASS;S1\nHypercar;1;2")))

    // ------------------------------------------------------------ the fastest

    @Test
    def testFastestOfEachClass(): Unit \ Assert =
        match fastestSectors(rowsOf(feed())) {
            case Ok(each) =>
                Assert.assertTrue(of("Hypercar", each) == Some(List#{59000, 70000, 80000}));
                Assert.assertTrue(of("LMGT3", each) == Some(List#{40000, 50000, 60000}))
            case Err(_) => Assert.assertTrue(false)
        }

    /// A nought is the lap the feed never recorded, so it never displaces a time,
    /// and a blank is not a time either.
    @Test
    def testNoughtIsNoTime(): Unit \ Assert =
        Assert.assertTrue(millisOf("1:23.456") == 83456);
        Assert.assertTrue(millisOf("1:02:03") == 3723000);
        Assert.assertTrue(millisOf("1.500") == 1500);
        Assert.assertTrue(millisOf("0.000") == -1);
        Assert.assertTrue(millisOf("") == -1)

    /// A sector time no reader can make of is refused by name rather than counted as
    /// no time, which would make it the fastest of the round.
    @Test
    def testUnreadableTimeIsRefused(): Unit \ Assert =
        Assert.assertTrue(complains("abc", decode("x.csv", "CLASS;S1;S2;S3\nHypercar;abc;1.000;2.000")))

    /// The field whole is the fastest of the classes, which is the reading the
    /// summary's shares are counted from. It comes last: the classes come in the
    /// order the feed listed them, which is the sport's order and not an
    /// alphabetical one.
    @Test
    def testFieldWholeIsPooledFromTheClasses(): Unit \ Assert =
        match fastestSectors(rowsOf(feed())) {
            case Ok(each) =>
                Assert.assertTrue(of(whole(), each) == Some(List#{40000, 50000, 60000}));
                Assert.assertTrue(List.length(each) == 3);
                Assert.assertTrue(Option.map(ran -> ran#carClass, List.last(each)) == Some(whole()))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testClassWithoutEverySectorIsRefused(): Unit \ Assert =
        Assert.assertTrue(
            complains(
                "Algarve recorded no time in every sector",
                fastestSectors(rowsOf("CLASS;S1;S2;S3\nAlgarve;1.000;2.000;"))
            )
        )

    @Test
    def testLapWithoutClassIsRefused(): Unit \ Assert =
        Assert.assertTrue(complains("names no class", decode("x.csv", "CLASS;S1;S2;S3\n;1.000;2.000;3.000")))

    // --------------------------------------------------------------- the shares

    @Test
    def testSharesOfALap(): Unit \ Assert =
        let shares = sharesOf(times(100000, 200000, 300000));
        Assert.assertTrue(List.length(shares) == 3);
        Assert.assertTrue(closeTo(1.0 / 6.0, List.get(0, shares)));
        Assert.assertTrue(closeTo(1.0 / 3.0, List.get(1, shares)));
        Assert.assertTrue(closeTo(1.0 / 2.0, List.get(2, shares)))

    /// The shares are a whole lap, which is what the export in the tree is asked to
    /// agree with.
    @Test
    def testSharesAreAWholeLap(): Unit \ Assert =
        match fastestSectors(rowsOf(feed())) {
            case Ok(each) =>
                let field = Option.map(ran -> sharesOf(ran#times), ran(whole(), each));
                Assert.assertTrue(closeTo(1.0, Option.getWithDefault(0.0, Option.map(total, field))))
            case Err(_) => Assert.assertTrue(false)
        }

    /// The map's intermediate lines, and not the line the lap is measured from,
    /// which stands at nought and at the end.
    @Test
    def testImpliedLinesPlaceTheIntermediateLines(): Unit \ Assert =
        let at = placesOf(times(60000, 60000, 60000), circuitMap());
        Assert.assertTrue(List.length(at) == 2);
        Assert.assertTrue(closeTo(5515.0 / 3.0, List.get(0, at)));
        Assert.assertTrue(closeTo(2.0 * 5515.0 / 3.0, List.get(1, at)))

    /// The mean speed over each of the map's stretches, which is what a sector time
    /// taken for a share of the distance hides.
    @Test
    def testSpeedsOverEachStretch(): Unit \ Assert =
        Assert.assertTrue(speeds(times(60000, 60000, 60000), circuitMap()) == List#{"120.0", "90.0", "120.9"})

    // ---------------------------------------------------------------- the map

    /// The line is `s2` because the second sector begins at it, and the last stretch
    /// ends at the line the lap is measured from, which is not a line to place. The
    /// names are the ones the geometry gives them too: the two readers of a
    /// circuit's map call one place by one name.
    @Test
    def testPublishedLines(): Unit \ Assert =
        match publishedLines(List#{2000.0, 1500.0, 2015.0}, 5515.0) {
            case Ok(lines) =>
                Assert.assertTrue(List.length(lines) == 2);
                Assert.assertTrue(List.map(line -> line#id, lines) == List#{"s2", "s3"});
                Assert.assertTrue(List.get(0, lines)#metres == 2000.0);
                Assert.assertTrue(List.get(1, lines)#metres == 3500.0)
            case Err(_) => Assert.assertTrue(false)
        }

    /// The one thing the stretches may be compared against is the lap length they
    /// add up to.
    @Test
    def testStretchesThatDoNotAddUpAreRefused(): Unit \ Assert =
        Assert.assertTrue(complains("add up to", publishedLines(List#{2000.0, 1500.0, 2015.0}, 6000.0)))

    // --------------------------------------------------------------- the seasons

    @Test
    def testMovementLaysOneSeasonAgainstTheOther(): Unit \ Assert =
        let season = placed("Hypercar", List#{1000.0, 3000.0}) :: placed("Algarve", List#{500.0, 1500.0}) :: Nil;
        let against = placed("Hypercar", List#{990.0, 3020.0}) :: placed("LMGT3", List#{700.0, 2100.0}) :: Nil;
        let shift = movement(season, against);
        let moved = Option.map(each -> each#positions, List.find(each -> each#carClass == "Hypercar", shift#compared));
        // Signed: which way round the lap the line moved.
        Assert.assertTrue(moved == Some(List#{10.0, -20.0}));
        // A class that ran one season only is named apart, from either side.
        Assert.assertTrue(shift#oneSeasonOnly == List#{"Algarve", "LMGT3"});
        // Judged on the widest move of the classes that ran both seasons.
        Assert.assertTrue(shift#furthest == 20.0)

    /// Nothing compared stands at nought, not at minus infinity.
    @Test
    def testMovementOfNothingCompared(): Unit \ Assert =
        Assert.assertTrue(movement(Nil, Nil)#furthest == 0.0)

    // -------------------------------------------------------------- the columns

    @Test
    def testColumnsPrintAsTheSportPrintsThem(): Unit \ Assert =
        Assert.assertTrue(seconds(Duration.fromMillis(83456)) == "1:23.456");
        Assert.assertTrue(percent(1.0 / 3.0) == "33.33%");
        Assert.assertTrue(metres(1234.5) == "1,234.5");
        Assert.assertTrue(metres(5515.0) == "5,515.0");
        Assert.assertTrue(movedMetres(-5.2) == "-5.2 m");
        Assert.assertTrue(movedMetres(3.0) == "+3.0 m");
        Assert.assertTrue(count(5530) == "5,530");
        Assert.assertTrue(table(wide(7) :: wide(7) :: Nil, "Hypercar" :: "+1.0 m" :: Nil) == "Hypercar +1.0 m")

    def wide(width: Int32): Column = { name = "class", width = width }

    /// A line that moved backwards round the lap moved just as far, so the widest
    /// move is the largest distance and not the largest signed number: a pair of
    /// seasons whose every line stood further back would otherwise judge as the
    /// smallest move there was.
    @Test
    def testFurthestMoveIsHowFarAndNotWhichWay(): Unit \ Assert =
        let season = placed("Hypercar", List#{-10.0, -300.0}) :: Nil;
        let against = placed("Hypercar", List#{0.0, 0.0}) :: Nil;
        Assert.assertTrue(movement(season, against)#furthest == 300.0)

}
