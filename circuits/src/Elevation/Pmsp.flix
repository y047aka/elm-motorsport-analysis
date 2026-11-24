/// The Prefeitura de São Paulo's 2017 LiDAR survey: São Paulo alone.
///
/// It is published as 5,544 LAZ tiles in an S3 bucket, on SIRGAS 2000 / UTM 23S, and as no
/// service a place can be asked of. The tiles are named by the city's map sheets, which
/// are not squares on that grid, so which tile holds a place is read off every tile's own
/// header, whose extent stands at a fixed offset in its first 227 bytes. The tiles a place
/// stands within reach of are then read through, and only their ground returns (class 2)
/// near some place are kept.
///
/// A place's height is the median of the ground returns within 1 m of it, or within 1.5 m
/// where none stands that near: under a bridge the ground holds no return. The sample's
/// resolution is the radius it was read within.
pub mod Elevation.Pmsp {

    import com.github.mreutegg.laszip4j.LASReader
    import java.io.InputStream
    import java.lang.{Double => JDouble}
    import java.net.URLEncoder
    import java.nio.charset.StandardCharsets

    use Geodesy.Place
    use Geodesy.Utm.Grid
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https

    pub def service(): String = "https://laz-m3dc-pmsp.s3.sa-east-1.amazonaws.com"

    def who(): String = "PMSP LiDAR 2017"

    def radii(): List[Float64] = 1.0 :: 1.5 :: Nil

    def reach(): Float64 = 1.5

    def ground(): Int16 = 2i16

    /// What a tile's header says of it: where its points stand, and how its stored
    /// integers come to metres.
    pub type alias Tile = {
        name   = String,
        scale  = (Float64, Float64, Float64),
        offset = (Float64, Float64, Float64),
        west   = Float64,
        east   = Float64,
        south  = Float64,
        north  = Float64
    }

    /// One ground return, in metres on the zone.
    pub type alias Return = {
        east  = Float64,
        north = Float64,
        up    = Float64
    }

    pub def sample(places: List[Place]): Result[String, List[Elevation.Sample]] \ { IO, Https } =
        let grids = List.map(Geodesy.Utm.gridOf(23, true), places);
        let cells = List.foldLeft((kept, at) -> List.foldLeft((acc, cell) -> Set.insert(cell, acc), kept, around(at)), Set.empty(), grids);
        forM(
            names   <- tileNames(None, Nil);
            heads   <- Service.openings(List.map(urlOf, names), 227, who());
            tiles   <- List.zip(names, heads) |> Result.traverse(match (name, head) -> tileOf(name, head));
            wanted  = List.filter(tile -> List.exists(within(tile), grids), tiles);
            kept    <- wanted |> Result.traverse(tile -> Service.streamed(urlOf(tile#name), who(), groundNear(tile, cells)));
            byCell  = cellsOf(List.flatten(kept));
            heights <- List.zip(places, grids) |> Result.traverse(match (at, grid) -> heightAt(byCell, at, grid))
        ) yield heights

    def urlOf(name: String): String = "${service()}/${name}"

    // ---------------------------------------------------------------- the bucket

    /// Every tile's key, a page of the bucket's listing at a time.
    def tileNames(token: Option[String], kept: List[String]): Result[String, List[String]] \ { IO, Https } =
        let url = match token {
            case None        => "${service()}/?list-type=2"
            case Some(after) => "${service()}/?list-type=2&continuation-token=${URLEncoder.encode(after, StandardCharsets.UTF_8)}"
        };
        match Elevation.sentHolding(HttpRequest.get(url), who(), "<ListBucketResult") {
            case Err(problem) => Err(problem)
            case Ok(page) =>
                let names = List.append(kept, keysOf(page));
                match continuationOf(page) {
                    case None        => Ok(names)
                    case Some(after) => tileNames(Some(after), names)
                }
        }

    /// The LAZ keys a page of an S3 listing names, in its order.
    pub def keysOf(page: String): List[String] =
        String.splitOn({substr = "<Key>"}, page)
            |> List.drop(1)
            |> List.map(String.takeWhile(c -> c != '<'))
            |> List.filter(String.endsWith({suffix = ".laz"}))

    /// The token a truncated listing hands on, if the listing was truncated.
    pub def continuationOf(page: String): Option[String] =
        match String.splitOn({substr = "<NextContinuationToken>"}, page) {
            case _ :: rest :: _ => Some(String.takeWhile(c -> c != '<', rest))
            case _              => None
        }

    // ---------------------------------------------------------------- a tile's header

    /// A tile's header read off its opening bytes, which every LAS version lays out alike
    /// up to the extent: scale factors at 131, offsets at 155, then max x, min x, max y and
    /// min y at 179, each a little-endian double.
    pub def tileOf(name: String, head: Vector[Int8]): Result[String, Tile] =
        if (Vector.length(head) < 211)
            Err("${who()} sent ${Vector.length(head)} bytes of ${name}'s header")
        else {
            let read = i -> doubleAt(head, i);
            Ok({
                name   = name,
                scale  = (read(131), read(139), read(147)),
                offset = (read(155), read(163), read(171)),
                east   = read(179),
                west   = read(187),
                north  = read(195),
                south  = read(203)
            })
        }

    def doubleAt(bytes: Vector[Int8], start: Int32): Float64 =
        let bits = List.foldRight(
            (i, acc) -> Int64.bitwiseOr(Int64.leftShift(acc, 8), Int64.bitwiseAnd(Int8.toInt64(Vector.get(start + i, bytes)), 255i64)),
            0i64,
            List.range(0, 8)
        );
        JDouble.longBitsToDouble(bits)

    def within(tile: Tile, at: Grid): Bool =
        at#east >= tile#west - reach() and at#east <= tile#east + reach() and
        at#north >= tile#south - reach() and at#north <= tile#north + reach()

    // ---------------------------------------------------------------- the points

    /// A cell of the grid the returns are sorted into, as wide as the farthest a return
    /// is read from a place: every return within reach of a place stands in the place's
    /// own cell or one beside it.
    def cellOf(east: Float64, north: Float64): Int64 =
        let column = Float64.tryToInt64(Float64.floor(east / reach())) |> Option.getWithDefault(0i64);
        let row = Float64.tryToInt64(Float64.floor(north / reach())) |> Option.getWithDefault(0i64);
        column * 100000000i64 + row

    def around(at: Grid): List[Int64] =
        let centre = cellOf(at#east, at#north);
        List.flatMap(column -> List.map(row -> centre + column * 100000000i64 + row, -1i64 :: 0i64 :: 1i64 :: Nil), -1i64 :: 0i64 :: 1i64 :: Nil)

    /// The ground returns of one tile that stand in a cell some place is read from.
    def groundNear(tile: Tile, cells: Set[Int64], stream: InputStream): Result[String, List[Return]] \ IO =
        let (xScale, yScale, zScale) = tile#scale;
        let (xOffset, yOffset, zOffset) = tile#offset;
        let walk = LASReader.getPoints(stream).iterator();
        def next(kept: List[Return]): List[Return] \ IO =
            if (not walk.hasNext())
                kept
            else {
                let point = walk.next();
                if (point.getClassification() != ground())
                    next(kept)
                else {
                    let east = Int32.toFloat64(point.getX()) * xScale + xOffset;
                    let north = Int32.toFloat64(point.getY()) * yScale + yOffset;
                    if (Set.memberOf(cellOf(east, north), cells))
                        next({east = east, north = north, up = Int32.toFloat64(point.getZ()) * zScale + zOffset} :: kept)
                    else
                        next(kept)
                }
            };
        Ok(next(Nil))

    pub def cellsOf(returns: List[Return]): Map[Int64, List[Return]] =
        List.foldLeft((acc, one) -> Map.insertWith((more, have) -> List.append(more, have), cellOf(one#east, one#north), one :: Nil, acc), Map.empty(), returns)

    // ---------------------------------------------------------------- a place's height

    /// The median of the ground returns within the nearest radius any stands within.
    pub def heightAt(byCell: Map[Int64, List[Return]], at: Place, grid: Grid): Result[String, Elevation.Sample] =
        let near = around(grid) |> List.flatMap(cell -> Map.getWithDefault(cell, Nil, byCell));
        let read = radii() |> List.findMap(radius -> {
            let inside = List.filter(one -> square(one#east - grid#east) + square(one#north - grid#north) <= square(radius), near);
            if (List.isEmpty(inside)) None
            else Some({place = at, metres = millimetres(median(List.map(one -> one#up, inside))), resolution = radius})
        });
        match read {
            case Some(sample) => Ok(sample)
            case None         => Err("${who()} holds no ground return within ${Geometry.Write.number(reach())} m of ${Geometry.Write.coordinate(at#lon, at#lat)}")
        }

    def square(x: Float64): Float64 = x * x

    def median(heights: List[Float64]): Float64 =
        let sorted = List.sort(heights);
        let count = List.length(sorted);
        let at = i -> List.drop(i, sorted) |> List.head |> Option.getWithDefault(0.0);
        if (Int32.remainder(count, 2) == 1) at(count / 2)
        else (at(count / 2 - 1) + at(count / 2)) / 2.0

    def millimetres(metres: Float64): Float64 = Float64.round(metres * 1000.0) / 1000.0
}
