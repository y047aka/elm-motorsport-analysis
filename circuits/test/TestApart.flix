/// The comparison both the diff command and the atlas reading run on: the sampling
/// bound, the tie, the nought-length stretch and the walk to a place along a line, each
/// held to its fixture. The sphere these are measured on, the projection and the metre
/// are `TestGeodesy`'s. `TestDiff` drives the arguments and the drawing that one of
/// these readings is printed with; `TestGeometry` the reading of a file.
pub mod TestApart {

    import java.lang.Math

    use Apart.{apartness, interpolate, line, nearestOn, toSegment}
    use Geodesy.Point

    /// A line of the fixture's: `100.0` metres of drawing standing at height `y`, each
    /// place with the metre it stands at.
    def along(y: Float64): List[Apart.Metred] =
        {point = {x = 0.0, y = y}, metre = 0.0} :: {point = {x = 100.0, y = y}, metre = 100.0} :: Nil

    def twoPoints(): List[Point] =
        {x = 0.0, y = 0.0} :: {x = 100.0, y = 0.0} :: Nil

    def hypot(a: Float64, b: Float64): Float64 = unsafe IO { Math.hypot(a, b) }

    /// A reading's failure, or the absence of one.
    def complains(problem: String, asked: Result[String, Apart.Apartness]): Bool =
        match asked {
            case Err(reading) => String.contains({substr = problem}, reading)
            case Ok(_)        => false
        }

    @Test
    def testOnlyAMetrePerPointMakesALine(): Unit \ Assert =
        match line(twoPoints(), 0.0 :: 100.0 :: Nil) {
            case Ok(metred) =>
                Assert.assertTrue(List.length(metred) == 2);
                Assert.assertTrue(Option.map(each -> each#point#x == 100.0 and each#metre == 100.0, List.nth(1, metred)) == Some(true))
            case Err(problem) => Assert.assertTrueWithMsg(false, "a metre per point is a line: ${problem}")
        };
        match line(twoPoints(), 0.0 :: Nil) {
            case Ok(_) => Assert.fail("a line short of its metres")
            case Err(problem) =>
                Assert.assertTrueWithMsg(String.contains({substr = "1 metres for 2 points"}, problem), problem)
        };
        match line(twoPoints(), 0.0 :: 100.0 :: 200.0 :: Nil) {
            case Ok(_) => Assert.fail("a line long of its metres")
            case Err(_) => ()
        }

    @Test
    def testInterpolateWalksALineByItsOwnMetres(): Unit \ Assert =
        let at = interpolate(along(0.0), 40.0);
        Assert.assertTrue(at#x == 40.0);
        Assert.assertTrue(at#y == 0.0);
        let zero = interpolate(along(0.0), 0.0);
        Assert.assertTrueWithMsg(zero#x == 0.0, "the lap's own zero");
        // A zero-length stretch is walked through, not divided by.
        let still = {point = {x = 0.0, y = 0.0}, metre = 0.0}
            :: {point = {x = 0.0, y = 0.0}, metre = 0.0}
            :: {point = {x = 5.0, y = 0.0}, metre = 5.0}
            :: Nil;
        let past = interpolate(still, 2.5);
        Assert.assertTrue(past#x == 2.5);
        Assert.assertTrue(past#y == 0.0)

    @Test
    def testNearestOnProjectsAPlaceOntoALine(): Unit \ Assert =
        let corner = {point = {x = 0.0, y = 0.0}, metre = 0.0}
            :: {point = {x = 10.0, y = 0.0}, metre = 10.0}
            :: {point = {x = 10.0, y = 10.0}, metre = 20.0}
            :: Nil;
        let near = nearestOn(corner, {x = 5.0, y = 3.0});
        Assert.assertTrue(near#metres == 5.0);
        Assert.assertTrue(near#distance == 3.0);
        // Beyond the end it clamps to the corner, not beyond.
        let past = nearestOn(corner, {x = 12.0, y = 12.0});
        Assert.assertTrue(past#metres == 20.0);
        Assert.assertTrue(abs(past#distance - hypot(2.0, 2.0)) < 0.0000000001)

    @Test
    def testApartnessSamplesOneLineAgainstAnotherAtItsOwnSpacing(): Unit \ Assert =
        match apartness(along(0.0), along(5.0), 25.0) {
            case Ok(read) =>
                // 0, 25, 50, 75 — the lap's own end is not sampled twice.
                Assert.assertTrue(read#count == 4);
                // Two parallel lines 5 apart are 5 apart everywhere.
                Assert.assertTrue(abs(read#mean - 5.0) < 0.0000000001);
                // All equal: the first sample is the worst.
                Assert.assertTrue(read#worst#aMetres == 0.0);
                Assert.assertTrue(read#worst#bMetres == 0.0);
                Assert.assertTrue(read#worst#distance == 5.0)
            case Err(problem) => Assert.assertTrueWithMsg(false, "read the two lines: ${problem}")
        }

    @Test
    def testApartnessRefusesALineWhoseOwnMetresNeverLeaveZero(): Unit \ Assert =
        let measured = "nothing is measured along the sampled line: its own metres end at 0 m";
        let standing = {point = {x = 0.0, y = 0.0}, metre = 0.0} :: Nil;
        Assert.assertTrue(complains(measured, apartness(standing, along(5.0), 25.0)));
        Assert.assertTrue(complains("its own metres end at 0 m", apartness(Nil, along(5.0), 25.0)))

    @Test
    def testToSegmentClampsToAStretchAndKnowsAPlaceThatIsOne(): Unit \ Assert =
        let start = {x = 0.0, y = 0.0};
        let end = {x = 10.0, y = 0.0};
        let near = toSegment(start, end, {x = 4.0, y = 3.0});
        Assert.assertTrue(abs(near#distance - 3.0) < 0.0000000001);
        Assert.assertTrue(abs(near#at - 0.4) < 0.0000000001);
        // Before the start is at the start, and after the end at the end.
        Assert.assertTrue(toSegment(start, end, {x = -5.0, y = 0.0})#at == 0.0);
        Assert.assertTrue(toSegment(start, end, {x = 15.0, y = 0.0})#at == 1.0);
        // A stretch of nought length is a place rather than a stretch.
        let standing = toSegment(start, start, {x = 3.0, y = 4.0});
        Assert.assertTrue(standing#distance == 5.0);
        Assert.assertTrue(standing#at == 0.0)

    def abs(x: Float64): Float64 = Math.abs(x)
}
