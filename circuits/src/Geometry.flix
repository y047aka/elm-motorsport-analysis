/// The reading of this repository's own geometry-file profile: the outline as the line it
/// claims to be — its points, its own metres, the properties a report quotes — and the pit
/// lane beside it. The diff, the atlas reading, the regeneration fence and the survey's
/// own comparison all read a kept file through this module, so what a file is refused
/// for is one set of refusals wherever it is read.
///
/// What is checked here is what the profile claims of a line: a basis among the kinds its
/// readers know, one metre per point, none of them going backwards, and points enough to be a
/// line. The claims that belong to a circuit — that the last metre stands at *its* published
/// length, that published stretches add up — are the reader that knows the circuit's. Every
/// failure names the file it was reading, because a kept file is as often a stranger's as
/// it is this repository's.
pub mod Geometry {

    use Geodesy.Place
    use Util.Json.Json

    /// The extension a geometry file of this profile is written with: how a directory
    /// listing tells its geometries from anything else standing there, and how a line
    /// is named after the file it was read from.
    pub def extension(): String =
        ".geojson"

    /// One feature of a geometry file: its members as the file's JSON gives them. The
    /// role that picks a feature out of a file lives inside its properties.
    pub type alias Feature = Map[String, Json]

    /// One geometry laid against the others: the name to quote in every failure,
    /// what a report should print beside the figures, the degrees as GeoJSON gives
    /// them, and the line's own metres.
    pub type alias Line = {
        name   = String,
        props  = Props,
        coords = List[Place],
        metres = List[Float64]
    }

    /// The properties a report quotes about a line: which kind of line it is, and
    /// where it came from. The metres are the line's own and travel in `Line`
    /// rather than here; the rest of what a file carries — a circuit, a survey
    /// time, a frame — is what the drawing reads, and a report quoting it would be
    /// a drawing.
    pub type alias Props = {
        basis   = String,
        source  = Option[String],
        license = Option[String]
    }

    /// The kinds of line a file of this profile may name as its `basis`: the
    /// OpenStreetMap centreline, stretched to a published lap, and a midline
    /// measured off orthoimagery at its own length. What a reader may trust a line
    /// for turns on which of the two it is — one ends where the published lap says,
    /// the other is not expected to — so a file naming a basis outside these is
    /// either a kind of line no reader has been told about yet, or an edited file.
    pub def bases(): List[String] =
        "osm-centreline" :: "measured-midline" :: Nil

    /// The outline of a kept file, read from its text.
    pub def outline(name: String, text: String): Result[String, Line] =
        match found(text, name, "outline") {
            case Err(problem)       => Err(problem)
            case Ok((props, shape)) => outlineOf(props, shape, name)
        }

    /// The pit lane beside the outline: a line with no metres.
    pub def pitLane(name: String, text: String): Result[String, List[Place]] =
        match found(text, name, "pit_lane") {
            case Err(problem) => Err(problem)
            case Ok((_, shape)) =>
                match placesOf("pit lane", shape) {
                    case Ok(Nil)     => Err("${name}: the pit lane holds no coordinates")
                    case Ok(line)    => Ok(line)
                    case Err(problem) => Err("${name}: ${problem}")
                }
        }

    /// The outline's own claims, checked in the order the profile makes them: a
    /// basis a reader knows, points to draw, metres of its own, a metre per point,
    /// and none of them behind the one before.
    def outlineOf(props: Map[String, Json], shape: Json, name: String): Result[String, Line] =
        match word("basis", props) {
            case Some(spelled) =>
                if (not List.memberOf(spelled, bases()))
                    Err(basisRefused(Some(spelled), name))
                else
                    measured(spelled, props, shape, name)
            case None => Err(basisRefused(None, name))
        }

    def measured(basis: String, props: Map[String, Json], shape: Json, name: String): Result[String, Line] =
        match placesOf("outline", shape) {
            case Err(problem) => Err("${name}: ${problem}")
            case Ok(coords) =>
                if (List.isEmpty(coords))
                    Err("${name}: the outline holds no points to draw")
                else
                    match numbersAt("metres", props) {
                        case Err(problem) => Err("${name}: ${problem}")
                        case Ok(None)     => Err("${name}: the outline publishes no metres")
                        case Ok(Some(metres)) =>
                            let points = List.length(coords);
                            if (List.length(metres) != points)
                                Err("${name}: ${List.length(metres)} metres for ${points} points")
                            else
                                match backwardsIn(metres) {
                                    case None     => Ok({name = name, props = quoted(basis, props), coords = coords, metres = metres})
                                    case Some(at) => Err("${name}: metres go backwards at point ${at}")
                                }
                    }
        }

    /// The sentence for a basis outside the kinds a reader knows, quoting what the
    /// file said — including when it said nothing at all, which is the edited file.
    def basisRefused(spelled: Option[String], name: String): String =
        match spelled {
            case None      => "${name}: the outline names basis nothing, which is not a line this repository reads"
            case Some(one) => "${name}: the outline names basis \"${one}\", which is not a line this repository reads"
        }

    /// The first point whose metre stands behind the one before it.
    def backwardsIn(metres: List[Float64]): Option[Int32] =
        backwards(Nil, metres)

    def backwards(seen: List[Float64], rest: List[Float64]): Option[Int32] =
        match (seen, rest) {
            case (_, one :: two :: more) =>
                if (two < one) Some(List.length(seen) + 1) else backwards(one :: seen, two :: more)
            case _ => None
        }

    /// What a report prints beside the figures: the kind of line and where it came
    /// from. The basis is the one `outlineOf` read and recognised. The file's other
    /// properties are left in the file.
    def quoted(basis: String, props: Map[String, Json]): Props = {
        basis   = basis,
        source  = word("source", props),
        license = word("license", props)
    }

    // ------------------------------------------------------------------ the file

    /// A file's feature of one role: its properties and its geometry — a geometry
    /// file's properties are what a line is claimed to be, and its `geometry` member
    /// is where the coordinates stand. The sentence for a file holding no such
    /// feature is made here, from the role.
    def found(text: String, name: String, role: String): Result[String, (Map[String, Json], Json)] =
        match Util.Json.parse(text) {
            case Err(problem) => Err("${name}: ${problem}")
            case Ok(json) =>
                match byRole(role, featuresOf(json)) {
                    case Some(one) => Ok(one)
                    case None      => Err("${name}: the geometry holds no ${called(role)} feature")
                }
        }

    /// A role as the sentence about a geometry lacking one calls it.
    def called(role: String): String =
        if (role == "pit_lane") "pit lane" else role

    /// All the file's features. The regeneration fence walks every one of two files
    /// rather than the one of each role a line is read out of.
    pub def featuresOf(json: Json): List[Feature] =
        match json {
            case Json.JObject(root) =>
                match Map.get("features", root) {
                    case Some(Json.JArray(items)) =>
                        List.filterMap(each -> match each {case Json.JObject(m) => Some(m), case _ => None}, Vector.toList(items))
                    case _ => Nil
                }
            case _ => Nil
        }

    def byRole(role: String, some: List[Feature]): Option[(Map[String, Json], Json)] =
        some
            |> List.find(each -> word("role", propertiesOf(each)) == Some(role))
            |> Option.map(one -> (propertiesOf(one), Map.get("geometry", one) |> Option.getWithDefault(Json.JNull)))

    /// A feature's properties. A feature carrying none picks nothing.
    pub def propertiesOf(feature: Feature): Map[String, Json] =
        match Map.get("properties", feature) {
            case Some(Json.JObject(props)) => props
            case _                         => Map.empty()
        }

    // ------------------------------------------------------------- the JSON, read

    /// The positions a geometry member lists, all-or-nothing: a line's coordinates read
    /// as `Ok` hold a place for every position the file wrote.
    def placesOf(role: String, shape: Json): Result[String, List[Place]] =
        match shape {
            case Json.JObject(members) =>
                match Map.get("coordinates", members) {
                    case Some(Json.JArray(items)) => places(role, Vector.toList(items))
                    case _                        => Err("the ${role} holds no coordinates")
                }
            case _ => Err("the ${role} holds no coordinates")
        }

    /// The positions a GeoJSON file lists as the places of a line: lon first, then lat,
    /// then the elevation a file sometimes records — and nothing after that. One
    /// position that is not a pair of degrees refuses the whole line, naming the
    /// position it stumbled at: a line read with a hole dropped in it is a shorter
    /// line, and a reader laying one against another could not tell a file surveyed
    /// shorter from one a reading thinned. This is the project's one reading of
    /// coordinates — `Midline` measures an atlas line with it too.
    pub def places(role: String, positions: List[Json]): Result[String, List[Place]] =
        walked(role, Nil, positions, 1)

    def walked(role: String, kept: List[Place], rest: List[Json], at: Int32): Result[String, List[Place]] =
        match rest {
            case Nil => Ok(List.reverse(kept))
            case one :: more =>
                match pair(one) {
                    case Some(place) => walked(role, place :: kept, more, at + 1)
                    case None        => Err("the ${role} is not a pair of degrees at position ${at}")
                }
        }

    /// One position: lon and lat, the elevation GeoJSON sometimes records after them
    /// and nothing past it. A reading that took a pair out of a longer position would
    /// be guessing at what the third number was.
    def pair(json: Json): Option[Place] =
        match json {
            case Json.JArray(items) =>
                match Vector.toList(items) {
                    case east :: north :: rest =>
                        if (List.length(rest) > 1)
                            None
                        else
                            match (number(east), number(north)) {
                                case (Some(lon), Some(lat)) => Some({lon = lon, lat = lat})
                                case _                      => None
                            }
                    case _ => None
                }
            case _ => None
        }

    /// A word the file carries, a number it carries, the list of them it carries.
    /// Each is `None` for the wrong kind of member as well as for an absent one:
    /// what a reading does with a `"basis": 3` is refuse the file, and the sentence
    /// it refuses with says the basis is unnamed.
    pub def word(key: String, props: Map[String, Json]): Option[String] =
        match Map.get(key, props) {
            case Some(Json.JString(spelled)) => Some(spelled)
            case _                           => None
        }

    pub def number(json: Json): Option[Float64] =
        match json {
            case Json.JNumber(spelled) => Float64.fromString(BigDecimal.toPlainString(spelled))
            case _                     => None
        }

    /// The numbers a file carries under one key: `Ok(None)` where it carries no such
    /// key, and an `Err` naming the entry where the key holds something that is not a
    /// number. A `metres` array holding a string is not a file that published no
    /// metres — it published a metre the reading could not read, and says so.
    def numbersAt(key: String, props: Map[String, Json]): Result[String, Option[List[Float64]]] =
        match Map.get(key, props) {
            case Some(Json.JArray(items)) =>
                match counted(key, Nil, Vector.toList(items), 0) {
                    case Err(problem) => Err(problem)
                    case Ok(numbers)  => Ok(Some(numbers))
                }
            case _ => Ok(None)
        }

    def counted(key: String, kept: List[Float64], rest: List[Json], at: Int32): Result[String, List[Float64]] =
        match rest {
            case Nil => Ok(List.reverse(kept))
            case one :: more =>
                match number(one) {
                    case Some(value) => counted(key, value :: kept, more, at + 1)
                    case None        => Err("${key} entry ${at} is not a number")
                }
        }
}
