/// An answer from OpenStreetMap, read: its elements, what each is tagged, and the moment
/// the map it surveyed was surveyed.
///
/// One shape answers both questions this project asks, and which of them was asked
/// decides which parts of it are filled:
///
///   * `Query.survey` answers `out body`, so a way carries the node ids its line runs
///     through and a node carries its degrees — which is what `Survey` chains a lap out
///     of, and what is kept beside a circuit stays the runner's own bytes, evidence
///     another reader can re-read years later.
///   * `Query.ways` answers `out geom`, so a way carries its line in degrees and no node
///     comes at all — which is the only answer a role's length can be measured out of,
///     and a probe report is worth nothing kept.
///
/// An element missing its `type` or its `id` is a refusal and not an element to skip: a
/// report printing a relation whose id is nought is worse than one that says what was
/// wrong. What an answer need not carry — tags, members, a node's degrees on a way — is
/// absent rather than a hole.
///
/// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; this is a
/// derivative of their tags.
pub mod Overpass.Answer {

    use Geodesy.Place
    use Util.Json.Json
    use Util.Json.FromJson

    /// Whatever a relation or a way is tagged, in OpenStreetMap's own spellings. Only
    /// `oneway` is read out of these; the rest travels with the answer it came in.
    pub type alias Tags = Map[String, String]

    /// One member of a relation. The role is the empty string for the ways a lap is
    /// chained from, which is the whole difference between the lap and the pit lane.
    pub type alias Member = {
        kind = String,
        role = String,
        ref  = Int64
    }

    /// One element of an answer, of whichever kind it was, with the parts its question
    /// filled: a node a place and no line, a way the node ids its line runs through or
    /// the line itself, a relation its members.
    pub type alias Element = {
        id      = Int64,
        kind    = String,
        tags    = Tags,
        at      = Option[Place],
        nodes   = List[Int64],
        line    = List[Place],
        members = List[Member]
    }

    /// An answer, read. `surveyedAt` is the answer's own stamp — which moment of the map
    /// it surveyed — and is the one property of a written geometry a live regeneration is
    /// allowed to move while every degree stands still.
    pub type alias Answer = {
        elements   = List[Element],
        surveyedAt = Option[String]
    }

    /// An answer's text, read. What is no JSON at all failed to answer, and says so with
    /// the parser's own words; whether a body is an answer at all is `Overpass.kept`,
    /// which is asked of a service's body before this is given it.
    pub def read(text: String): Result[String, Answer] =
        match Util.Json.parse(text) {
            case Err(problem) => Err("${problem}")
            case Ok(json) =>
                let root = objectOf(json);
                Result.map(
                    elements -> {elements = elements, surveyedAt = stamped(root)},
                    Result.traverse(elementOf, array("elements", root))
                )
        }

    /// An element's kind and id are what makes it an element: an answer that names one
    /// without either said something this reading does not understand.
    def elementOf(json: Json): Result[String, Element] =
        forM(
            kind    <- decodeAtKey("type", json);
            id      <- decodeAtKey("id", json);
            tags    <- tagsOf(json);
            at      <- atOf(json);
            nodes   <- nodesOf(json);
            line    <- lineOf(json);
            members <- membersOf(json)
        ) yield {id = id, kind = kind, tags = tags, at = at, nodes = nodes, line = line, members = members}

    /// A node's place — a way has no latitude of its own, and an answer that carries one
    /// of the two degrees and not the other is not a place.
    def atOf(json: Json): Result[String, Option[Place]] =
        match (latitude("lat", json), latitude("lon", json)) {
            case (Ok(Some(lat)), Ok(Some(lon))) => Ok(Some({lat = lat, lon = lon}))
            case (Ok(None), Ok(None))           => Ok(None)
            case (Err(problem), _)              => Err(problem)
            case (_, Err(problem))              => Err(problem)
            case _                              => Err("an answer gives one of lat, lon and not the other")
        }

    def latitude(key: String, json: Json): Result[String, Option[Float64]] =
        decodeAtKeyOpt(key, json)

    /// A way's node refs. A reference that is no number is a line this reading cannot
    /// chain, so the whole answer is refused rather than the reference dropped.
    def nodesOf(json: Json): Result[String, List[Int64]] =
        each(whole, arrayAt("nodes", json))

    /// A way's line, as `out geom` handed it inline. The node's id and tags travel with
    /// each point and are nothing to a length.
    def lineOf(json: Json): Result[String, List[Place]] =
        each(placeOf, arrayAt("geometry", json))

    def placeOf(json: Json): Result[String, Place] =
        forM(
            lat <- decodeAtKey("lat", json);
            lon <- decodeAtKey("lon", json)
        ) yield {lat = lat, lon = lon}

    /// Tags the answer need not carry: a way is tagged and a relation's point is not, and
    /// neither is a failure to read the other.
    def tagsOf(json: Json): Result[String, Tags] =
        decodeAtKeyOpt("tags", json) |> Result.map(tags -> Option.getWithDefault(Map.empty(), tags))

    def membersOf(json: Json): Result[String, List[Member]] =
        each(memberOf, arrayAt("members", json))

    /// A relation's member: what kind of thing it is, which line it is on, and what it
    /// stands for. A role the answer does not spell is the empty one, which is the lap's.
    def memberOf(json: Json): Result[String, Member] =
        forM(
            kind <- decodeAtKey("type", json);
            role <- decodeAtKeyOpt("role", json);
            ref  <- decodeAtKey("ref", json)
        ) yield {kind = kind, role = Option.getWithDefault("", role), ref = ref}

    /// The moment the answer says the map was surveyed at, or nothing where it says none.
    def stamped(root: Map[String, Json]): Option[String] =
        match Map.get("osm3s", root) {
            case Some(osm) =>
                match osm {
                    case Json.JObject(members) =>
                        match Map.get("timestamp_osm_base", members) {
                            case Some(Json.JString(spelled)) => Some(spelled)
                            case _                           => None
                        }
                    case _ => None
                }
            case None => None
        }

    /// A list the answer need not carry: absent, it is nothing; present, each item is
    /// read by the reading that knows what an item of it is.
    def each(read: Json -> Result[String, a], value: Result[String, Option[List[Json]]]): Result[String, List[a]] =
        match value {
            case Err(problem) => Err(problem)
            case Ok(None)     => Ok(Nil)
            case Ok(Some(js)) => Result.traverse(read, js)
        }

    /// An array the answer need not carry at all: a relation has members and a node has
    /// no geometry.
    def arrayAt(key: String, json: Json): Result[String, Option[List[Json]]] =
        decodeAtKeyOpt(key, json)

    // ------------------------------------------------------------------ the JSON, read

    def objectOf(json: Json): Map[String, Json] =
        match json {
            case Json.JObject(members) => members
            case _                     => Map.empty()
        }

    def array(key: String, root: Map[String, Json]): List[Json] =
        match Map.get(key, root) {
            case Some(Json.JArray(items)) => Vector.toList(items)
            case _                        => Nil
        }

    /// A whole number: an id, a node reference. The answer's ids are far inside what a
    /// double holds exactly, so a plain spelling is read as a float and cut to a whole
    /// rather than looked for as an integer the answer never writes.
    def whole(json: Json): Result[String, Int64] =
        match json {
            case Json.JNumber(spelled) =>
                match Float64.fromString(BigDecimal.toPlainString(spelled)) {
                    case Some(spelledNumber) => Ok(Float64.truncateToInt64(spelledNumber))
                    case None                => Err("a number no double reads")
                }
            case _ => Err("a whole number the answer spelled as something else")
        }

    def decodeAtKey(key: String, json: Json): Result[String, a] with FromJson[a] =
        FromJson.decodeAtKey(key, json) |> Result.mapErr(e -> "${e}")

    def decodeAtKeyOpt(key: String, json: Json): Result[String, Option[a]] with FromJson[a] =
        FromJson.decodeAtKeyOpt(key, json) |> Result.mapErr(e -> "${e}")
}
