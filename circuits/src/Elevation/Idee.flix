/// The Instituto Geográfico Nacional's terrain model of Spain at 5 m (MDT05), asked
/// through the IDEE's WCS: one coverage of the box the places stand in, answered as an
/// ESRI ASCII grid inside a multipart body, and each place read off it between the four
/// cell centres around it.
///
/// The coverage is laid in ETRS89 degrees, which stand within a metre of the WGS84 ones
/// the places are surveyed in.
pub mod Elevation.Idee {

    use Geodesy.Place
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https

    pub def service(): String =
        "https://servicios.idee.es/wcs-inspire/mdt"

    pub def coverage(): String = "Elevacion4258_5"

    /// Degrees added round the box the places stand in, so every place has four cell
    /// centres round it.
    def margin(): Float64 = 0.0005

    pub def sample(places: List[Place]): Result[String, List[Elevation.Sample]] \ { IO, Https } =
        Elevation.sentHolding(HttpRequest.get(urlOf(places)), "IGN MDT05", "ncols")
            |> Result.flatMap(gridOf)
            |> Result.flatMap(grid -> Result.traverse(heightOn(grid), places))

    pub def urlOf(places: List[Place]): String =
        let lons = List.map(at -> at#lon, places);
        let lats = List.map(at -> at#lat, places);
        let low = xs -> List.minimum(xs) |> Option.getWithDefault(0.0);
        let high = xs -> List.maximum(xs) |> Option.getWithDefault(0.0);
        let n = Geometry.Write.number;
        "${service()}?SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCoverage&COVERAGEID=${coverage()}&SUBSET=Long(${n(low(lons) - margin())},${n(high(lons) + margin())})&SUBSET=Lat(${n(low(lats) - margin())},${n(high(lats) + margin())})&FORMAT=ArcGrid"

    /// An ASCII grid: its size, the corner of its south-west cell and the cell's size in
    /// degrees, and its heights a row at a time from the north.
    pub type alias Grid = {
        columns = Int32,
        rows    = Int32,
        west    = Float64,
        south   = Float64,
        cell    = Float64,
        nodata  = Option[Float64],
        heights = Vector[Float64]
    }

    /// The grid out of the body: the first part's text after its headers, up to the
    /// boundary that closes it.
    pub def gridOf(body: String): Result[String, Grid] =
        let start = String.indexOf({substr = "ncols"}, body);
        match start {
            case None => Err("IGN MDT05 answered no grid")
            case Some(at) =>
                let text = String.dropLeft(at, body);
                let ends = String.indexOf({substr = "\n--"}, text) |> Option.getWithDefault(String.length(text));
                gridIn(String.takeLeft(ends, text))
        }

    def gridIn(text: String): Result[String, Grid] =
        let words = String.words(text);
        let header = key -> headerOf(key, words);
        let heights = List.drop(headerLength(words), words) |> List.filterMap(Float64.fromString);
        match (header("ncols"), header("nrows"), header("xllcorner"), header("yllcorner"), header("cellsize")) {
            case (Some(c), Some(r), Some(x), Some(y), Some(s)) =>
                let columns = Float64.truncateToInt32(c);
                let rows = Float64.truncateToInt32(r);
                if (List.length(heights) != columns * rows)
                    Err("IGN MDT05 gave ${List.length(heights)} heights for a grid of ${columns} by ${rows}")
                else
                    Ok({columns = columns, rows = rows, west = x, south = y, cell = s, nodata = header("nodata_value"), heights = List.toVector(heights)})
            case _ => Err("IGN MDT05 answered a grid with no header")
        }

    /// The header's keys, as an ASCII grid may spell them.
    def isKey(word: String): Bool =
        List.memberOf(String.toLowerCase(word), "ncols" :: "nrows" :: "xllcorner" :: "yllcorner" :: "cellsize" :: "nodata_value" :: Nil)

    /// How many words the header takes: a key and its value each.
    def headerLength(words: List[String]): Int32 =
        match words {
            case key :: _ :: more if isKey(key) => 2 + headerLength(more)
            case _ => 0
        }

    def headerOf(key: String, words: List[String]): Option[Float64] =
        match words {
            case one :: value :: more =>
                if (String.toLowerCase(one) == key) Float64.fromString(value)
                else if (isKey(one)) headerOf(key, more)
                else None
            case _ => None
        }

    /// A place's height between the four cell centres round it.
    pub def heightOn(grid: Grid, at: Place): Result[String, Elevation.Sample] =
        let fx = (at#lon - grid#west) / grid#cell - 0.5;
        let fy = (grid#south + Int32.toFloat64(grid#rows) * grid#cell - at#lat) / grid#cell - 0.5;
        let i = Float64.truncateToInt32(Float64.floor(fx));
        let j = Float64.truncateToInt32(Float64.floor(fy));
        let tx = fx - Int32.toFloat64(i);
        let ty = fy - Int32.toFloat64(j);
        match (cellOf(grid, i, j), cellOf(grid, i + 1, j), cellOf(grid, i, j + 1), cellOf(grid, i + 1, j + 1)) {
            case (Some(a), Some(b), Some(c), Some(d)) =>
                let top = a + (b - a) * tx;
                let bottom = c + (d - c) * tx;
                Ok({place = at, metres = top + (bottom - top) * ty, resolution = 5.0})
            case _ => Err("IGN MDT05 holds no height at ${Geometry.Write.coordinate(at#lon, at#lat)}")
        }

    def cellOf(grid: Grid, column: Int32, row: Int32): Option[Float64] =
        if (column < 0 or row < 0 or column >= grid#columns or row >= grid#rows)
            None
        else
            Vector.nth(row * grid#columns + column, grid#heights)
                |> Option.filter(height -> Some(height) != grid#nodata)
}
