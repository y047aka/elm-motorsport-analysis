/// The comparison both the diff command and the atlas reading run on: the sampling
/// bound, the tie, the nought-length stretch and the walk to a place along a line, each
/// held to its fixture. The sphere these are measured on, the projection and the metre
/// are `TestGeodesy`'s. `TestDiff` drives the arguments and the drawing that one of
/// these readings is printed with; `TestGeometry` the reading of a file.
pub mod TestApart {

    import java.lang.Math

    use Apart.{apartness, interpolate, nearestOn, toSegment}
    use Geodesy.Point

    def along(y: Float64): List[Point] =
        {x = 0.0, y = y} :: {x = 100.0, y = y} :: Nil

    def metres(): List[Float64] =
        0.0 :: 100.0 :: Nil

    def hypot(a: Float64, b: Float64): Float64 = unsafe IO { Math.hypot(a, b) }

    /// A reading's failure, or the absence of one.
    def complains(problem: String, asked: Result[String, Apart.Apartness]): Bool =
        match asked {
            case Err(reading) => String.contains({substr = problem}, reading)
            case Ok(_)        => false
        }

    @Test
    def testInterpolateWalksALineByItsOwnMetres(): Unit \ Assert =
        let at = interpolate(along(0.0), metres(), 40.0);
        Assert.assertTrue(at#x == 40.0);
        Assert.assertTrue(at#y == 0.0);
        let zero = interpolate(along(0.0), metres(), 0.0);
        Assert.assertTrueWithMsg(zero#x == 0.0, "the lap's own zero");
        // A zero-length stretch is walked through, not divided by.
        let still = {x = 0.0, y = 0.0} :: {x = 0.0, y = 0.0} :: {x = 5.0, y = 0.0} :: Nil;
        let past = interpolate(still, 0.0 :: 0.0 :: 5.0 :: Nil, 2.5);
        Assert.assertTrue(past#x == 2.5);
        Assert.assertTrue(past#y == 0.0)

    @Test
    def testNearestOnProjectsAPlaceOntoALine(): Unit \ Assert =
        let corner = {x = 0.0, y = 0.0} :: {x = 10.0, y = 0.0} :: {x = 10.0, y = 10.0} :: Nil;
        let near = nearestOn({x = 5.0, y = 3.0}, corner, 0.0 :: 10.0 :: 20.0 :: Nil);
        Assert.assertTrue(near#metres == 5.0);
        Assert.assertTrue(near#distance == 3.0);
        // Beyond the end it clamps to the corner, not beyond.
        let past = nearestOn({x = 12.0, y = 12.0}, corner, 0.0 :: 10.0 :: 20.0 :: Nil);
        Assert.assertTrue(past#metres == 20.0);
        Assert.assertTrue(abs(past#distance - hypot(2.0, 2.0)) < 0.0000000001)

    @Test
    def testApartnessSamplesOneLineAgainstAnotherAtItsOwnSpacing(): Unit \ Assert =
        match apartness(along(0.0), metres(), along(5.0), metres(), 25.0) {
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
        Assert.assertTrue(complains(measured, apartness({x = 0.0, y = 0.0} :: Nil, 0.0 :: Nil, along(5.0), metres(), 25.0)));
        Assert.assertTrue(complains("its own metres end at 0 m", apartness(Nil, Nil, along(5.0), metres(), 25.0)))

    @Test
    def testToSegmentClampsToAStretchAndKnowsAPlaceThatIsOne(): Unit \ Assert =
        let start = {x = 0.0, y = 0.0};
        let end = {x = 10.0, y = 0.0};
        let near = toSegment({x = 4.0, y = 3.0}, start, end);
        Assert.assertTrue(abs(near#distance - 3.0) < 0.0000000001);
        Assert.assertTrue(abs(near#at - 0.4) < 0.0000000001);
        // Before the start is at the start, and after the end at the end.
        Assert.assertTrue(toSegment({x = -5.0, y = 0.0}, start, end)#at == 0.0);
        Assert.assertTrue(toSegment({x = 15.0, y = 0.0}, start, end)#at == 1.0);
        // A stretch of nought length is a place rather than a stretch.
        let standing = toSegment({x = 3.0, y = 4.0}, start, start);
        Assert.assertTrue(standing#distance == 5.0);
        Assert.assertTrue(standing#at == 0.0)

    def abs(x: Float64): Float64 = Math.abs(x)
}
