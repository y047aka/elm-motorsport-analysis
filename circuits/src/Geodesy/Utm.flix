/// A place in the metres of a Universal Transverse Mercator zone on SIRGAS 2000 (EPSG:319xx),
/// the plane a São Paulo LiDAR tile is written on, as proj4j projects it.
///
/// This is not `Geodesy`'s plane and its metres are not the drawing's: it is asked only so a
/// place can be found among a tile's points.
pub mod Geodesy.Utm {

    import org.locationtech.proj4j.CRSFactory
    import org.locationtech.proj4j.CoordinateTransformFactory
    import org.locationtech.proj4j.ProjCoordinate

    use Geodesy.Place

    /// Metres east and north of the zone's false origin.
    pub type alias Grid = {
        east  = Float64,
        north = Float64
    }

    /// A place on the zone numbered `zone`, south of the equator when `south` is set. The
    /// definitions are EPSG's own as PROJ spells them, so no EPSG database is asked for.
    pub def gridOf(zone: Int32, south: Bool, at: Place): Grid = unsafe IO {
        let factory = new CRSFactory();
        let degrees = factory.createFromParameters("WGS84", "+proj=longlat +datum=WGS84 +no_defs");
        let hemisphere = if (south) " +south" else "";
        let grid = factory.createFromParameters("SIRGAS 2000 / UTM ${zone}", "+proj=utm +zone=${zone}${hemisphere} +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs");
        let projected = new CoordinateTransformFactory().createTransform(degrees, grid).transform(new ProjCoordinate(at#lon, at#lat), new ProjCoordinate());
        {east = projected.x, north = projected.y}
    }
}
