/// What OpenStreetMap says a relation is, before anyone draws from it: how far a
/// place widens into a box, what a relation's own tags claim about itself, which
/// tags could name a circuit at all, and what an answer says about the roles its
/// members carry. `Probe` is the command that asks; this is the reading of an
/// answer already got, opening nothing and reaching no network.
///
/// Every distance here is a ground distance on the sphere every drawing of a
/// circuit is measured on -- the sphere `Motorsport.Circuit.Geodesy` projects
/// through and the one this project's `Apart.flix` measures its comparisons with,
/// and the one a probe has to agree with or its lengths mean nothing to the survey
/// they are being read before.
///
/// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; what a
/// reading here prints is a derivative of their tags.
pub mod Candidates {

    import java.lang.Math

    use Overpass.Element
    use Overpass.Member
    use Overpass.Place
    use Overpass.Tags

    /// A box on the earth, degrees, as Overpass takes it: south, west, north, east.
    pub type alias Box = {
        s = Float64,
        w = Float64,
        n = Float64,
        e = Float64
    }

    /// The metres one degree comes to — on `Apart`'s sphere, the one every
    /// drawing of a circuit is measured on. Spelled once there rather than
    /// again here, because a probe measured on another sphere prints a lap the
    /// survey will not measure, and that lap is the one reading a config is
    /// authored from.
    def degreesToMetres(): Float64 = Apart.radians() * Apart.earthMetres()

    /// The box's own rounding of a degree, which is not `degreesToMetres`: a probe
    /// asks how far round a place to look, and a box a tenth of a kilometre wide of
    /// the mark costs a relation standing in the next box over. The survey a probe
    /// is read before measures with the sphere above rather than with this.
    def kilometresPerLatitudeDegree(): Float64 = 111.32

    /// The two calls every distance here is measured with. Flix's effect checker
    /// asks a call into Java to be `IO` and has not been told that these two read
    /// nothing but their arguments; the cast says so to it, which is what keeps
    /// every reading here pure enough for a test to hand it a fixture.
    def cos(degrees: Float64): Float64 = unsafe IO { Math.cos(degrees * (Math.PI / 180.0)) }

    def metresBetween(x: Float64, y: Float64): Float64 = unsafe IO { Math.hypot(x, y) }

    /// Metres between two places, east-west taken at the parallel of the second --
    /// an approximation only ever asked of distances across a circuit's few
    /// kilometres.
    pub def apart(a: Place, b: Place): Float64 =
        let east = cos(b#lat);
        metresBetween(b#lat - a#lat, (b#lon - a#lon) * east) * degreesToMetres()

    /// Metres along a line of places, each stretch taken at its own parallel.
    pub def polylineMetres(points: List[Place]): Float64 =
        List.zip(points, List.drop(1, points))
            |> List.map(stretch -> match stretch {
                case (north, south) => apart(north, south)
            })
            |> List.foldLeft((total, metres) -> total + metres, 0.0)

    /// `s,w,n,e` as given, or a `lat,lon` centre widened by the radius: so many km
    /// per degree of latitude, and that times the cosine of the parallel for
    /// longitude -- which is why the box a centre opens is wider east-west than it
    /// is north-south, and why a probe of Le Mans reaches further east than north.
    pub def bboxOf(place: String, radiusKm: Float64): Result[String, Box] =
        match numbers(place) {
            case None => Err("neither a centre nor a box: ${place}")
            case Some(parts) =>
                match parts {
                    case s :: w :: n :: e :: Nil =>
                        if (s >= n or w >= e)
                            Err("the box does not open north-east: ${place}")
                        else
                            Ok({ s = s, w = w, n = n, e = e })
                    case lat :: lon :: Nil =>
                        let km = kilometresPerLatitudeDegree();
                        let north = radiusKm / km;
                        let east = radiusKm / (km * cos(lat));
                        Ok({ s = lat - north, w = lon - east, n = lat + north, e = lon + east })
                    case _ => Err("neither a centre nor a box: ${place}")
                }
        }

    /// The numbers a place is made of, all of them or none. A part that is no
    /// number is not dropped: `north,east` reads as a place to whoever typed it,
    /// and the answer it gets has to say that it is neither.
    def numbers(place: String): Option[List[Float64]] =
        let spelled = List.map(Float64.fromString, String.splitOn({substr = ","}, place));
        if (List.exists(Option.isEmpty, spelled))
            None
        else
            Some(List.map(each -> Option.getWithDefault(0.0, each), spelled))

    /// What the tags say, before any geometry is asked for: what kind of relation
    /// it is, what it is called, and the length the tags themselves claim -- the
    /// Sarthe relation tags its own `distance` as 13.626, and a probe's reader
    /// picks the full circuit out of the answer with that number.
    pub def describe(tags: Tags): String =
        let kinds = List.filterMap(key -> tagOf(key, tags), List#{"type", "route", "sport"});
        let name = List.filterMap(key -> Map.get(key, tags), List#{"name", "name:en", "alt_name"});
        let claimed = match Map.get("distance", tags) {
            case None     => ""
            case Some(km) => ", tags say ${km} km"
        };
        let called = match name {
            case first :: _ => first
            case _          => "(unnamed)"
        };
        "${String.intercalate(" ", kinds)}  \"${called}\"${claimed}"

    def tagOf(key: String, tags: Tags): Option[String] =
        Option.map(value -> "${key}=${value}", Map.get(key, tags))

    /// Whether the tags could name a circuit, which is not the same question as
    /// whether they name one: a road and an administrative boundary both catch a
    /// probe box, and neither is a relation whose ways could be chained into a
    /// lap.
    pub def looksLikeACircuit(tags: Tags): Bool =
        let route = spelled("route", tags);
        let sport = spelled("sport", tags);
        if (spelled("type", tags) == "circuit" or Map.memberOf("motorsport", tags))
            true
        else if (spelled("highway", tags) == "raceway")
            true
        else if (String.startsWith({prefix = "motor"}, sport))
            true
        else if (spelled("type", tags) == "route")
            List.exists(word -> String.contains({substr = word}, route), List#{"motor", "rally", "rac", "circ"})
                or List.exists(entry -> match entry {
                    case (key, _) => String.startsWith({prefix = "raceway:"}, key)
                }, Map.toList(tags))
        else
            false

    def spelled(key: String, tags: Tags): String =
        Option.getWithDefault("", Map.get(key, tags))

    /// The relation's ways, measured: how many there are and under which roles,
    /// and the length of the ones a lap would be chained from -- ways with no
    /// role, which is the role the pipeline chains and the kept geometries carry.
    /// Ways may overlap or double back at a pit complex, so the sum is an estimate
    /// beside the tags' own claim and not a second survey. The answer is one
    /// already got; asking for it is `Probe`'s.
    pub def measure(answer: List[Element], relation: Int64): Result[String, String] =
        match relationOf(answer, relation) {
            case None => Err("the answer holds no relation ${relation}")
            case Some(rel) =>
                let tallies = tally(rel#members, answer);
                let lap = Option.getWithDefault(unmeasured(""), held(tallies, ""));
                let roles = List.map(tallyOf, tallies) |> String.intercalate(", ");
                let pitNote = match pitOf(tallies) {
                    case None    => ""
                    case Some(p) => ", pit ${whole(p#metres)} m"
                };
                let nodes = nodeRoles(rel#members);
                let nodeNote = match nodes {
                    case Nil => ""
                    case _   => "; nodes: ${String.intercalate(", ", nodes)}"
                };
                Ok(
                    "lap ${whole(lap#metres)} m over ${lap#ways} unroled way${plural(lap#ways)}${pitNote}; roles: ${roles}${nodeNote}"
                )
        }

    /// How many ways a role carries and how far they run. The roles are held in the
    /// order the answer first showed each of them rather than in alphabetical
    /// order, because the report prints the roles as the relation carries them and
    /// `(none)` belongs at the front of it.
    pub type alias Tally = {
        role   = String,
        ways   = Int32,
        metres = Float64
    }

    /// One role as the report prints it. The role a lap is chained from prints as
    /// `(none)`, since the empty string is not a thing a reader can see.
    def tallyOf(entry: Tally): String =
        let named = if (entry#role == "") "(none)" else entry#role;
        "${named}: ${entry#ways} way${plural(entry#ways)}"

    /// A role the answer carries no ways under: the lap the report prints a length
    /// for may be a role the relation never uses.
    def unmeasured(role: String): Tally = { role = role, ways = 0, metres = 0.0 }

    def tally(members: List[Member], answer: List[Element]): List[Tally] =
        List.foldLeft(
            (entries, member) ->
                if (member#kind != "way")
                    entries
                else
                    add(member#role, polylineMetres(wayOf(answer, member#ref)), entries),
            Nil,
            members
        )

    def add(role: String, metres: Float64, entries: List[Tally]): List[Tally] =
        if (List.exists(entry -> entry#role == role, entries))
            List.map(
                entry ->
                    if (entry#role == role)
                        { role = role, ways = entry#ways + 1, metres = entry#metres + metres }
                    else
                        entry,
                entries
            )
        else
            List.append(entries, List#{ { role = role, ways = 1, metres = metres } })

    /// The roles of a relation's *nodes*, which answer a different question from
    /// its ways: which line the relation says the lap is measured from. COTA's
    /// relation names two, 297 m apart along the lap, and the config a probe leads
    /// to has to say which one its metres are measured from.
    def nodeRoles(members: List[Member]): List[String] =
        List.filterMap(
            member ->
                if (member#kind != "way" and not String.isEmpty(member#role))
                    Some(member#role)
                else
                    None,
            members
        )

    /// A way's line by the id a member refers to. An answer lists its elements
    /// flat, so the ways are looked for in it rather than gathered first: a probe
    /// walks a relation's dozen ways, not a country's road network.
    def wayOf(answer: List[Element], ref: Int64): List[Place] =
        match List.find(element -> element#kind == "way" and element#id == ref, answer) {
            case None       => Nil
            case Some(way)  => way#line
        }

    /// The relation the answer was asked for. The probe asks for one relation by
    /// id, so an answer holding some other relation is a runner that answered a
    /// different question -- which is exactly what the failure says.
    def relationOf(answer: List[Element], relation: Int64): Option[Element] =
        List.find(element -> element#kind == "relation" and element#id == relation, answer)

    /// The pit lane's role, which OpenStreetMap has been tagged both ways: Le
    /// Mans's relation says `pit_lane` and plenty say `pit`.
    def pitOf(tallies: List[Tally]): Option[Tally] =
        match held(tallies, "pit_lane") {
            case None  => held(tallies, "pit")
            case found => found
        }

    def held(tallies: List[Tally], role: String): Option[Tally] =
        List.find(entry -> entry#role == role, tallies)

    /// A distance as the report prints it: whole metres, which is all a relation
    /// measured off an answer is worth.
    def whole(metres: Float64): String =
        "${Float64.truncateToInt64(Float64.floor(metres + 0.5))}"

    def plural(ways: Int32): String = if (ways == 1) "" else "s"
}
