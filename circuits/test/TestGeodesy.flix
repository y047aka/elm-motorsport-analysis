/// The sphere, the plane and the metre every other reading of this project is taken on:
/// the ground distance between two places, the parallel both lines of a comparison are
/// laid on, the projection that keeps `y` running south, the north-west corner a drawing
/// is measured from, the metres a line accumulates from its own zero, and the tenth a
/// distance is kept to. A second spelling of the radius fails no compile and prints
/// 13,627 m for the lap the survey measures at 13,612, so the one spelling is measured
/// here rather than only read.
///
/// `TestApart` drives what two lines laid on this plane come to; `TestSurvey` the lap
/// chained and stretched on it.
pub mod TestGeodesy {

    import java.lang.Math

    use Geodesy.{apart, cumulative, northWest, parallelOf, polylineMetres, projectOn, roundTenth}
    use Geodesy.Place
    use Geodesy.Point

    def point(pair: (Float64, Float64)): Point =
        match pair {
            case (x, y) => {x = x, y = y}
        }

    def line(points: List[(Float64, Float64)]): List[Point] = List.map(point, points)

    /// The sphere, measured here once: the survey stretches its metres with, the
    /// probe counts its laps through, and the report's implied lines place by is
    /// one `apart`, read at one radius.
    @Test
    def testApartMeasuresTheGroundOnOneSphere(): Unit \ Assert =
        // A degree of latitude is 111195.1 m at any parallel, and a degree of
        // longitude that much only on the equator — 96297.8 m at 30° — the one
        // approximation asked of distances across a circuit's few kilometres.
        let degree = abs(apart({lat = 30.0, lon = -97.6}, {lat = 31.0, lon = -97.6}) - 111195.1);
        Assert.assertTrue(degree < 0.1);
        Assert.assertTrue(abs(apart({lat = 0.0, lon = 0.0}, {lat = 0.0, lon = 1.0}) - 111195.1) < 0.1);
        let north = apart({lat = 30.0, lon = 0.0}, {lat = 30.0, lon = 1.0});
        Assert.assertTrue(north < 96297.8 + 0.1 and north > 96297.8 - 0.1);
        // A line is walked stretch by stretch, in order; nothing and one place are
        // nought metres, not a failure.
        Assert.assertTrue(abs(polylineMetres(Nil)) < 0.000001);
        Assert.assertTrue(abs(polylineMetres({lat = 0.0, lon = 0.0} :: Nil)) < 0.000001);
        let forth = polylineMetres({lat = 0.0, lon = 0.0} :: {lat = 0.0, lon = 1.0} :: {lat = 0.0, lon = 2.0} :: Nil);
        Assert.assertTrue(abs(forth - 222390.2) < 0.2)

    @Test
    def testTheProjectionIsOnePlaneAboutThePlacesOfBothLines(): Unit \ Assert =
        let places = {lon = 0.0, lat = 47.0} :: {lon = 0.0, lat = 48.0} :: Nil;
        // The mean latitude of both lines, not of the one being sampled along.
        Assert.assertTrue(abs(parallelOf(places) - 47.5) < 0.0000000001);
        let place = projectOn(0.0, {lon = 1.0, lat = 1.0});
        // Metres, on the sphere every drawing is measured on, and `y` south so that
        // north is up.
        Assert.assertTrue(abs(place#x - (1.0 * (Math.PI / 180.0) * 6371008.8)) < 0.01);
        Assert.assertTrue(place#y < 0.0)

    @Test
    def testTheCornerIsTheNorthWestOfEveryPlace(): Unit \ Assert =
        // The drawing's metres are measured from this corner, so no line of the drawing
        // falls below its own zero.
        let corner = northWest({lat = 30.0, lon = -97.6} :: {lat = 30.2, lon = -97.4} :: {lat = 29.9, lon = -97.9} :: Nil);
        Assert.assertTrue(corner#lat == 30.2);
        Assert.assertTrue(corner#lon == -97.9)

    @Test
    def testCumulativeRunsALineFromItsOwnZero(): Unit \ Assert =
        let metres = cumulative(line((0.0, 0.0) :: (3.0, 4.0) :: (3.0, 4.0) :: Nil));
        // Each stretch is its own hypotenuse, the sum runs forwards, and a stretch of no
        // length adds nothing rather than a NaN.
        Assert.assertTrue(metres == 0.0 :: 5.0 :: 5.0 :: Nil)

    @Test
    def testTenthsRoundUpAndHoldTheSurvey(): Unit \ Assert =
        // The tenth is what every baseline was rendered at, and half goes up.
        Assert.assertTrue(roundTenth(172.8) == 172.8);
        Assert.assertTrue(Geometry.Write.number(roundTenth(1.05)) == "1.1");
        Assert.assertTrue(Geometry.Write.number(roundTenth(1728.0)) == "1728");
        Assert.assertTrue(Geometry.Write.number(roundTenth(0.0)) == "0")

    def abs(x: Float64): Float64 = Math.abs(x)
}
