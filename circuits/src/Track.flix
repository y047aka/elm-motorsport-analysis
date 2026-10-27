/// The track-atlas line as this repository reads it: the shape checks that turn an atlas
/// feature into a line, a place or a fraction of a lap; the guards that keep a mismatched
/// file from being kept as one circuit's evidence; and the file it is written back into.
/// `Atlas` is the command; everything here opens nothing. The kept geometry the guards are
/// measured against is `Geometry`'s reading, shared with every other reader of a served
/// file, and the lap-origin guard asks the same question of a measured line's start that
/// `Survey` asks of a relation's finish node — at a wider allowance, because where a line
/// measured off orthoimagery begins is that survey's own choice.
///
/// A geometry is written back in this repository's spelling — `type` before `coordinates` —
/// and a number keeps the digits the layer spelled, so a point written here reads as the
/// layer wrote it.
///
/// The atlas data is © its contributors under the ODbL, itself derived from OpenStreetMap
/// and open orthoimagery.
pub mod Track {

    use Circuit.TimingLine
    use Geometry.Place
    use Util.Json.Json

    /// One feature of an atlas file: its members as the file's JSON gives them. The
    /// role that picks a feature out of a file lives inside its properties.
    pub type alias Feature = Map[String, Json]

    /// How far the start of a line measured off orthoimagery may stand from the
    /// published line and still be the same lap. Wider than `Circuit.nodeWithin`,
    /// which holds a relation's node: a relation tags the line itself, while where
    /// a measured line begins is that survey's own choice. `checkOrigin` holds
    /// every atlas lap to this one distance, not to a circuit's authored `within`.
    pub def measuredWithin(): Float64 = 25.0

    /// The file's features, whatever any of them is tagged with.
    pub def featuresOf(json: Json): List[Feature] =
        Geometry.featuresOf(json)

    /// What a feature's properties say it is, and what to call it in a sentence when
    /// they say nothing.
    pub def roleOf(feature: Feature): Option[String] =
        Geometry.word("role", Geometry.propertiesOf(feature))

    pub def named(feature: Feature): String =
        Option.getWithDefault("feature", roleOf(feature))

    // ---------------------------------------------------------------- the shapes

    /// An atlas outline as the line it measures: degrees, lon before lat. A line the
    /// reading does not understand is refused whole rather than measured with a hole in it.
    pub def lineOf(feature: Feature): Result[String, List[Place]] =
        match allPairs(positionsOf(feature)) {
            case Some(places) if List.length(places) >= 2 => Ok(places)
            case _                                        => Err("the atlas outline holds no line to measure")
        }

    /// An atlas point feature — a corner or a pit marker — as the place it stands at:
    /// a Point's coordinates are that pair itself, not a list of them, unlike the
    /// outline's LineString.
    pub def placeOf(feature: Feature): Result[String, Place] =
        match allNumbers(positionsOf(feature)) {
            case Some(lon :: lat :: Nil) => Ok({lon = lon, lat = lat})
            case _                       => Err("the atlas ${named(feature)} carries no point")
        }

    /// Where on the lap a corner or pit marker stands, as the atlas's fraction of it.
    pub def markerOf(feature: Feature): Result[String, Float64] =
        match Map.get("marker", Geometry.propertiesOf(feature)) {
            case Some(Json.JNumber(spelled)) =>
                match Float64.fromString(BigDecimal.toPlainString(spelled)) {
                    case Some(fraction) => Ok(fraction)
                    case None           => Err("the atlas ${named(feature)} carries no marker")
                }
            case _ => Err("the atlas ${named(feature)} carries no marker")
        }

    // ---------------------------------------------------------------- the JSON, read

    /// One position as a place, or nothing at all when it is not exactly two numbers.
    def pair(json: Json): Option[Place] =
        match json {
            case Json.JArray(items) =>
                match Vector.toList(items) {
                    case east :: north :: Nil =>
                        match (number(east), number(north)) {
                            case (Some(lon), Some(lat)) => Some({lon = lon, lat = lat})
                            case _                      => None
                        }
                    case _ => None
                }
            case _ => None
        }

    /// A feature's `geometry` member, and the `coordinates` inside it, one JSON value
    /// per position — written back from what the layer spelled, not from a reading of
    /// it. What makes a geometry a shape is its coordinates and not the word `type`:
    /// a marker carrying a pair of degrees is a point even when its `geometry` names
    /// no type at all, which is how the layer's own files stand.
    def shapeOf(feature: Feature): Option[Json] =
        match Map.get("geometry", feature) {
            case Some(shape) =>
                match shape {
                    case Json.JObject(members) =>
                        match Map.get("coordinates", members) {
                            case Some(Json.JArray(_)) => Some(shape)
                            case _                    => None
                        }
                    case _ => None
                }
            case None => None
        }

    def positionsOf(feature: Feature): List[Json] =
        match shapeOf(feature) {
            case Some(shape) =>
                match shape {
                    case Json.JObject(members) =>
                        match Map.get("coordinates", members) {
                            case Some(Json.JArray(items)) => Vector.toList(items)
                            case _                        => Nil
                        }
                    case _ => Nil
                }
            case None => Nil
        }

    /// The word a shape calls itself, which is `Point` for a marker that forgot to say.
    def shapeWord(shape: Json): String =
        match shape {
            case Json.JObject(members) =>
                match Map.get("type", members) {
                    case Some(Json.JString(spelled)) => spelled
                    case _                           => "Point"
                }
            case _ => "Point"
        }

    def number(json: Json): Option[Float64] =
        match json {
            case Json.JNumber(spelled) => Float64.fromString(BigDecimal.toPlainString(spelled))
            case _                     => None
        }

    /// The numbers a list of JSON values carries, or nothing at all when any of them is
    /// not a number.
    def allNumbers(items: List[Json]): Option[List[Float64]] =
        List.foldRight(
            (json, rest) -> match (number(json), rest) {
                case (Some(one), Some(many)) => Some(one :: many)
                case _                       => None
            },
            Some(Nil),
            items
        )

    /// The places a list of JSON positions carries, read the same all-or-nothing way.
    def allPairs(positions: List[Json]): Option[List[Place]] =
        List.foldRight(
            (position, rest) -> match (pair(position), rest) {
                case (Some(one), Some(many)) => Some(one :: many)
                case _                       => None
            },
            Some(Nil),
            positions
        )

    // ------------------------------------------------------------------- the guards

    /// The reading is kept under the word given on the command line, whatever the file
    /// was measured from: a mismatched pair replaces one circuit's kept evidence with
    /// another circuit's line. A file that names itself not at all is taken on the
    /// word's alone.
    pub def checkIdentity(claim: Option[String], slug: String): Result[String, Unit] =
        match claim {
            case None => Ok(())
            case Some(spelled) =>
                if (spelled == slug)
                    Ok(())
                else
                    Err("the atlas file names itself '${spelled}', not '${slug}' — it is not this circuit's line")
        }

    /// The atlas reading's share of the one question both pipelines ask: how far the
    /// measured lap's first point stands from the published line, and the failure when
    /// it starts another line over. A circuit that publishes no line asks nothing.
    /// The distance allowed is `measuredWithin`, not the line's `within`.
    pub def checkOrigin(first: Place, line: Option[TimingLine]): Result[String, Float64] =
        match line {
            case None => Ok(0.0)
            case Some(published) =>
                let distance = Apart.apart(first, published#place);
                if (distance > measuredWithin())
                    Err(
                        "the atlas lap is ${Util.Format.fixed(1, distance)} m from the published timing line, which is not within ${Util.Format.spelled(measuredWithin())} m. Its markers would be measured from the wrong line."
                    )
                else
                    Ok(distance)
        }

    // ---------------------------------------------------------- the published lines

    /// The claim a kept geometry carries of the lines the lap is timed to: the map
    /// they come from, and the stretches between them.
    pub type alias Sectors = {
        source    = String,
        stretches = List[Float64]
    }

    /// The intermediate timing lines a circuit's published stretches imply: each
    /// stretch ends where the next begins, and the last ends at the line the lap is
    /// measured from — which is where it started, so it is not a line to place. A line
    /// is named for the sector that begins at it, which is how the atlas reading and
    /// `Cli.TimingLines.Feed`'s `publishedLines` — over in the timing project, sharing
    /// only the geometry file — spell the same line the same thing. Stretches are
    /// trusted with the lap length they add up to and with nothing else, at
    /// `Circuit.stretchTolerance()`.
    pub type alias PublishedLine = {
        id     = String,
        metres = Float64
    }

    pub def sectorLines(sectors: Sectors, lap: Float64): Result[String, List[PublishedLine]] =
        let total = List.foldLeft((sum, stretch) -> sum + stretch, 0.0, sectors#stretches);
        if (Float64.abs(total - lap) > Circuit.stretchTolerance())
            Err("the sectors add up to ${Util.Format.spelled(total)} m, not the published ${Util.Format.spelled(lap)} m")
        else
            Ok(implied(Option.getWithDefault(Nil, List.init(sectors#stretches)), 0.0, 2, Nil))

    /// The lines the stretches imply, in order, each named for the sector that begins
    /// at it — the second sector begins at `s2`, which is why the counting starts there
    /// and not at one.
    def implied(stretches: List[Float64], at: Float64, sector: Int32, lines: List[PublishedLine]): List[PublishedLine] =
        match stretches {
            case Nil => List.reverse(lines)
            case one :: more =>
                let standing = at + one;
                implied(more, standing, sector + 1, {id = "s${sector}", metres = standing} :: lines)
        }

    /// The sectors a kept file's outline claims, or nothing at all when it claims
    /// none. Half a claim — a source with no stretches, stretches with no source — is
    /// no claim either.
    pub def sectorsClaimed(props: Map[String, Json]): Option[Sectors] =
        match Map.get("sectors", props) {
            case Some(Json.JObject(claim)) =>
                match (Map.get("source", claim), Map.get("stretches", claim)) {
                    case (Some(Json.JString(source)), Some(Json.JArray(items))) =>
                        match allNumbers(Vector.toList(items)) {
                            case Some(stretches) => Some({source = source, stretches = stretches})
                            case None            => None
                        }
                    case _ => None
                }
            case _ => None
        }

    // ---------------------------------------------------------------- the file out

    /// The atlas line in this repository's own profile, at its own length: it does not
    /// end at the published lap length, and `"stretched":false` says so at the properties
    /// a reader sees first. The outline's metres are the line's own, rounded to the
    /// tenth like every kept metre; a marker keeps the layer's own fraction, and the
    /// geometry the layer spelled.
    pub def fileText(
        source: String,
        slug: String,
        coords: List[Place],
        corners: List[Feature],
        pits: List[Feature],
        metres: List[Float64]
    ): String = {
        let length = Option.getWithDefault(0.0, List.last(metres));
        let outline =
            "{"
                + "\"type\":${Geometry.Write.text("Feature")},"
                + "\"properties\":{"
                + "\"role\":${Geometry.Write.text("outline")},"
                + "\"circuit\":${Geometry.Write.text(slug)},"
                + "\"basis\":${Geometry.Write.text("measured-midline")},"
                + "\"source\":${Geometry.Write.text(source)},"
                + "\"license\":${Geometry.Write.text("ODbL")},"
                + "\"lap_length_m\":${Geometry.Write.number(Survey.roundTenth(length))},"
                + "\"stretched\":false,"
                + "\"metres\":[${String.intercalate(",", List.map(metre -> Geometry.Write.number(Survey.roundTenth(metre)), metres))}]"
                + "},"
                + "\"geometry\":{\"type\":${Geometry.Write.text("LineString")},\"coordinates\":${degrees(coords)}}"
                + "}";
        let features = outline :: List.map(corner -> featureText("corner", corner), corners) ++ List.map(pit -> pitText(pit), pits);
        "{\"type\": \"FeatureCollection\", \"features\": [\n${String.intercalate(",\n", List.map(each -> "    ${each}", features))}\n]}\n"
    }

    /// A corner, as the file keeps it: its id, its place on the lap, and which way it
    /// turns — and nothing the layer did not carry.
    def featureText(role: String, feature: Feature): String =
        laidOut(
            "\"role\":${Geometry.Write.text(role)}" :: carried("id", feature) :: carried("marker", feature) :: carried("direction", feature) :: Nil,
            feature
        )

    /// A pit entry or exit, under the role the layer gave it.
    def pitText(feature: Feature): String =
        laidOut(
            "\"role\":${Geometry.Write.text(Option.getWithDefault("feature", roleOf(feature)))}" :: carried("name", feature) :: carried("marker", feature) :: Nil,
            feature
        )

    /// One feature, from the properties already spelled: type before properties before
    /// geometry, as every feature of this profile stands.
    def laidOut(claims: List[String], feature: Feature): String =
        "{\"type\":${Geometry.Write.text("Feature")},\"properties\":{${String.intercalate("", claims)}},\"geometry\":${geometryText(feature)}}"

    /// One property as the layer carries it, comma and all, or nothing when the layer
    /// holds no such property. A property the layer holds as JSON null is written as
    /// the null the layer wrote.
    def carried(key: String, feature: Feature): String =
        match Map.get(key, Geometry.propertiesOf(feature)) {
            case None       => ""
            case Some(json) => ",\"${key}\":${Util.Json.toCompactString(json)}"
        }

    /// A marker's place, its numbers as the layer spelled them, in the order this
    /// repository writes a geometry: type before coordinates.
    def geometryText(feature: Feature): String =
        match shapeOf(feature) {
            case None => "null"
            case Some(shape) =>
                let laid = List.map(positionText, positionsOf(feature));
                "{\"type\":${Geometry.Write.text(shapeWord(shape))},\"coordinates\":[${String.intercalate(",", laid)}]}"
        }

    def scalar(json: Json): String = Util.Json.toCompactString(json)

    /// A distance shown with the sign that says which line is longer.
    pub def signed(metres: Float64): String =
        if (metres >= 0.0) "+${Util.Format.fixed(1, metres)}" else Util.Format.fixed(1, metres)

    /// One position of a marker's geometry: a pair spelled as the layer spelled it,
    /// anything else as the JSON the file gives.
    def positionText(position: Json): String =
        match position {
            case Json.JArray(items) => "[${String.intercalate(",", List.map(scalar, Vector.toList(items)))}]"
            case other              => Util.Json.toCompactString(other)
        }

    /// A line's degrees, lon before lat, each written as this repository writes every
    /// kept number.
    def degrees(coords: List[Place]): String =
        "[${String.intercalate(",", List.map(place -> "[${Geometry.Write.number(place#lon)},${Geometry.Write.number(place#lat)}]", coords))}]"
}
