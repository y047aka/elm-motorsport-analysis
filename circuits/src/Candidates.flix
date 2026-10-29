/// What OpenStreetMap says a relation is, before anyone draws from it: how far a
/// place widens into a box, what a relation's own tags claim about itself, which
/// tags could name a circuit at all, and what an answer says about the roles its
/// members carry. `Probe` is the command that asks; this is the reading of an
/// answer already got, opening nothing and reaching no network.
///
/// Every distance here is measured through `Geodesy.flix` -- the project's one
/// spelling of the sphere -- and the measured lap is the one reading a config is
/// authored from.
///
/// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; what a
/// reading here prints is a derivative of their tags.
pub mod Candidates {

    use Geodesy.Place
    use Overpass.Answer.Element
    use Overpass.Answer.Member
    use Overpass.Answer.Tags

    /// A box on the earth, degrees, as Overpass takes it: south, west, north, east.
    pub type alias Box = {
        s = Float64,
        w = Float64,
        n = Float64,
        e = Float64
    }

    /// The box's own rounding of a degree, which is not `Apart`'s metres-per-degree:
    /// a box a tenth of a kilometre wide of the mark costs a relation standing in
    /// the next box over.
    def kilometresPerLatitudeDegree(): Float64 = 111.32

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
                        let east = radiusKm / (km * Geodesy.cos(lat));
                        Ok({ s = lat - north, w = lon - east, n = lat + north, e = lon + east })
                    case _ => Err("neither a centre nor a box: ${place}")
                }
        }

    /// A box as Overpass takes it in a query, and as the report echoes it back so that a
    /// reader can tell what was asked of the ground.
    pub def bounds(box: Box): String =
        "${box#s},${box#w},${box#n},${box#e}"

    /// The numbers a place is made of, all of them or none. A part that is no
    /// number is not dropped: `north,east` reads as a place to whoever typed it,
    /// and the answer it gets has to say that it is neither.
    def numbers(place: String): Option[List[Float64]] =
        let spelled = place |> String.splitOn({substr = ","}) |> List.map(Float64.fromString);
        if (List.exists(Option.isEmpty, spelled))
            None
        else
            Some(spelled |> List.map(each -> each |> Option.getWithDefault(0.0)))

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
        Map.get(key, tags) |> Option.getWithDefault("")

    /// The relation's ways, measured: how many there are and under which roles,
    /// and the length of the ones a lap would be chained from — ways with no
    /// role, which is the role the pipeline chains and the kept geometries carry.
    /// Ways may overlap or double back at a pit complex, so the sum is an estimate
    /// beside the tags' own claim and not a second survey. The measuring answers
    /// what it measured; the sentence it is printed in is `Probe`'s.
    pub type alias Measured = {
        lap       = Tally,
        pit       = Option[Tally],
        roles     = List[Tally],
        nodeRoles = List[String]
    }

    pub def measure(answer: List[Element], relation: Int64): Result[String, Measured] =
        let ways = answer |> Overpass.Answer.byKind("way");
        match answer |> Overpass.Answer.byKind("relation") |> Map.get(relation) {
            case None => Err("the answer holds no relation ${relation}")
            case Some(rel) =>
                let tallies = tally(rel#members, ways);
                let lap = held(tallies, "") |> Option.getWithDefault(unmeasured(""));
                Ok({lap = lap, pit = pitOf(tallies), roles = tallies, nodeRoles = nodeRoles(rel#members)})
        }

    /// How many ways a role carries and how far they run. The roles are held in the
    /// order the answer first showed each of them, so `(none)` belongs at the front.
    pub type alias Tally = {
        role   = String,
        ways   = Int32,
        metres = Float64
    }

    /// A role the answer carries no ways under: the lap the report prints a length
    /// for may be a role the relation never uses.
    def unmeasured(role: String): Tally = { role = role, ways = 0, metres = 0.0 }
    def tally(members: List[Member], ways: Map[Int64, Element]): List[Tally] =
        List.foldLeft(
            (entries, member) ->
                if (member#kind != "way")
                    entries
                else
                    add(member#role, Geodesy.polylineMetres(wayOf(ways, member#ref)), entries),
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

    /// A way's line under the id a member refers to; a member naming no way in the
    /// answer measures nought.
    def wayOf(ways: Map[Int64, Element], ref: Int64): List[Place] =
        match Map.get(ref, ways) {
            case None      => Nil
            case Some(way) => way#line
        }

    /// The pit lane's role, which OpenStreetMap has been tagged both ways: Le
    /// Mans's relation says `pit_lane` and plenty say `pit`.
    def pitOf(tallies: List[Tally]): Option[Tally] =
        match held(tallies, "pit_lane") {
            case None  => held(tallies, "pit")
            case found => found
        }

    def held(tallies: List[Tally], role: String): Option[Tally] =
        List.find(entry -> entry#role == role, tallies)
}
