/// A place in the metres of a Universal Transverse Mercator zone on the GRS80 ellipsoid,
/// which is what SIRGAS 2000 and ETRS89 survey in: the plane a LiDAR tile is written on.
///
/// This is not `Geodesy`'s plane and its metres are not the drawing's. It is asked only so
/// a place can be found among a tile's points, by Krüger's series to the sixth order of
/// the flattening (Karney 2011), which is good to well under a millimetre within a zone.
pub mod Geodesy.Utm {

    import java.lang.Math

    use Geodesy.Place

    /// Metres east and north of the zone's false origin.
    pub type alias Grid = {
        east  = Float64,
        north = Float64
    }

    /// The ellipsoid's equatorial semi-axis, in metres: an ellipsoid's, not the sphere the
    /// project measures on, which is `Geodesy.earthMetres`.
    def grs80Metres(): Float64 = 6378137.0

    def grs80Flattening(): Float64 = 1.0 / 298.257222101

    def scale(): Float64 = 0.9996

    /// A place on the zone numbered `zone`, south of the equator when `south` is set.
    pub def gridOf(zone: Int32, south: Bool, at: Place): Grid = unsafe IO {
        let f = grs80Flattening();
        let n = f / (2.0 - f);
        let n2 = n * n;
        let n3 = n2 * n;
        let n4 = n3 * n;
        let n5 = n4 * n;
        let n6 = n5 * n;
        let rectifying = grs80Metres() / (1.0 + n) * (1.0 + n2 / 4.0 + n4 / 64.0 + n6 / 256.0);
        let alphas =
            (n / 2.0 - 2.0 * n2 / 3.0 + 5.0 * n3 / 16.0 + 41.0 * n4 / 180.0 - 127.0 * n5 / 288.0 + 7891.0 * n6 / 37800.0) ::
            (13.0 * n2 / 48.0 - 3.0 * n3 / 5.0 + 557.0 * n4 / 1440.0 + 281.0 * n5 / 630.0 - 1983433.0 * n6 / 1935360.0) ::
            (61.0 * n3 / 240.0 - 103.0 * n4 / 140.0 + 15061.0 * n5 / 26880.0 + 167603.0 * n6 / 181440.0) ::
            (49561.0 * n4 / 161280.0 - 179.0 * n5 / 168.0 + 6601661.0 * n6 / 7257600.0) ::
            (34729.0 * n5 / 80640.0 - 3418889.0 * n6 / 1995840.0) ::
            (212378941.0 * n6 / 319334400.0) :: Nil;
        let radians = Geodesy.radians();
        let meridian = Int32.toFloat64(zone * 6 - 183);
        let phi = at#lat * radians;
        let lambda = (at#lon - meridian) * radians;
        let e = 2.0 * Math.sqrt(n) / (1.0 + n);
        let t = Math.sinh(atanh(Math.sin(phi)) - e * atanh(e * Math.sin(phi)));
        let xi0 = Math.atan2(t, Math.cos(lambda));
        let eta0 = atanh(Math.sin(lambda) / Math.sqrt(1.0 + t * t));
        let (xi, eta) = List.foldLeft(
            (acc, pair) -> match (acc, pair) {
                case ((x, y), (j, alpha)) =>
                    let k = 2.0 * Int32.toFloat64(j);
                    (x + alpha * Math.sin(k * xi0) * Math.cosh(k * eta0), y + alpha * Math.cos(k * xi0) * Math.sinh(k * eta0))
            },
            (xi0, eta0),
            List.zip(List.range(1, 7), alphas)
        );
        {
            east  = 500000.0 + scale() * rectifying * eta,
            north = (if (south) 10000000.0 else 0.0) + scale() * rectifying * xi
        }
    }

    def atanh(x: Float64): Float64 = unsafe IO { 0.5 * Math.log((1.0 + x) / (1.0 - x)) }
}
