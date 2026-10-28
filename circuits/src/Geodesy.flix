/// A place on earth, the sphere it is measured on, and the plane its metres are drawn
/// on: the units every reading in this project is taken in.
///
/// The app projects the same degrees through the same frame — the `Frame` written beside
/// every kept geometry is a copy of the one a survey was measured on, and
/// `Motorsport.Circuit.Geodesy` re-runs this projection rather than choosing one of its
/// own. A second spelling of `earthMetres` fails no compile and shows up only as a
/// distance: the equatorial radius prints 13,627 m for the lap this one measures at
/// 13,612, and the measured lap is the reading a circuit's config is authored from.
///
/// Two distances are asked here, and they are not the same reading. Between two places
/// it is a ground distance at circuit scale, east-west taken at the parallel of the
/// second — the one approximation asked of a circuit's few kilometres, and what a
/// timing line is held to. Along a line it is the sum of the hypotenuses of a projected
/// line's own stretches, each place keeping the metre it stands at; `Apart` is what
/// lays two such lines against each other.
pub mod Geodesy {

    import java.lang.Math

    /// A place on earth, in the degrees OpenStreetMap gives it. The one place type of the
    /// project: an answer's node, a geometry file's coordinate and a circuit's published
    /// timing line are all this, and the drawing reads the same degrees back.
    pub type alias Place = {
        lat = Float64,
        lon = Float64
    }

    /// A place of the plane a line is drawn on: metres east and south of the projection's
    /// own zero.
    pub type alias Point = {
        x = Float64,
        y = Float64
    }

    /// What a reading with nothing to read answers with.
    pub def zero(): Point = {x = 0.0, y = 0.0}

    /// The frame the degrees project through: its origin the north-west corner of the
    /// survey, `parallel` the latitude the east-west is scaled at. Written into every
    /// kept geometry whole, so the drawing's `Circuit.Geodesy` is a copy of this frame
    /// and never a re-derivation of one.
    pub type alias Frame = {
        origin   = Place,
        parallel = Float64
    }

    /// The earth every drawing is measured on, in metres.
    pub def earthMetres(): Float64 = 6371008.8

    pub def radians(): Float64 = Math.PI / 180.0

    /// Flix's effect checker asks a call into Java to be `IO` and has not been told
    /// that these read nothing but their arguments; the cast says so to it.
    pub def cos(degrees: Float64): Float64 = unsafe IO { Math.cos(degrees * radians()) }

    pub def hypot(east: Float64, south: Float64): Float64 = unsafe IO { Math.hypot(east, south) }

    /// The metres one degree of the sphere comes to, which is the sphere's own constant
    /// and not a second one: `projectOn` spells the same two factors for the plane.
    def degreesToMetres(): Float64 = radians() * earthMetres()

    // ---------------------------------------------------------------- the sphere

    /// Metres between two places, east-west taken at the parallel of the second — the
    /// one approximation asked of distances across a circuit's few kilometres, and the
    /// one the survey measures a timing line with and the probe measures its candidate
    /// lengths with.
    pub def apart(a: Place, b: Place): Float64 =
        hypot(b#lat - a#lat, (b#lon - a#lon) * cos(b#lat)) * degreesToMetres()

    /// Metres along a line of places, each stretch taken at its own parallel.
    pub def polylineMetres(points: List[Place]): Float64 =
        List.zipWith((ahead, behind) -> apart(ahead, behind), points, List.drop(1, points))
            |> List.foldLeft((total, metres) -> total + metres, 0.0)

    // ---------------------------------------------------------------- projection

    /// The parallel both lines are laid on: the mean latitude of every place on
    /// both lines together, so neither is drawn at a scale of its own.
    pub def parallelOf(places: List[Place]): Float64 =
        List.foldLeft((total, place) -> total + place#lat, 0.0, places) / Int32.toFloat64(List.length(places))

    /// Equirectangular about that parallel: metres, and `y` running south as SVG's does
    /// so that north is up. The origin is the zero of degrees, not a corner of either line.
    pub def projectOn(parallel: Float64, place: Place): Point = {
        x = place#lon * radians() * earthMetres() * cos(parallel),
        y = 0.0 - (place#lat * radians() * earthMetres())
    }

    /// The north-west corner of the survey: the drawing's metres are measured from it, so
    /// a line never falls below its own zero.
    pub def northWest(places: List[Place]): Place =
        match places {
            case Nil => {lat = 0.0, lon = 0.0}
            case first :: rest =>
                List.foldLeft(
                    (corner, place) -> {
                        lat = if (place#lat > corner#lat) place#lat else corner#lat,
                        lon = if (place#lon < corner#lon) place#lon else corner#lon
                    },
                    {lat = first#lat, lon = first#lon},
                    rest
                )
        }

    // ------------------------------------------------------------ metres along a line

    /// Metres round a line of drawing metres, each stretch its own hypotenuse, from the
    /// line's own zero. The sum runs forwards, so the figure a file carries as its
    /// surveyed length is reproducible.
    pub def cumulative(points: List[Point]): List[Float64] =
        match points {
            case Nil           => Nil
            case first :: rest => walkedBy(first, rest, 0.0, 0.0 :: Nil)
        }

    def walkedBy(ahead: Point, rest: List[Point], total: Float64, kept: List[Float64]): List[Float64] =
        match rest {
            case Nil => List.reverse(kept)
            case one :: more =>
                let step = total + hypot(one#x - ahead#x, one#y - ahead#y);
                walkedBy(one, more, step, step :: kept)
        }

    // ----------------------------------------------------------- the tenth kept to

    /// The tenths in a metre: the scale a distance is kept to — which is the tenth
    /// every baseline was rendered at.
    pub def tenthsPerMetre(): Float64 = 10.0

    /// A distance kept to that tenth: half goes up, which is the half JavaScript's
    /// `Math.round` sends up too.
    pub def roundTenth(metres: Float64): Float64 =
        Int64.toFloat64(Float64.truncateToInt64((metres * tenthsPerMetre()) + 0.5)) / tenthsPerMetre()
}
