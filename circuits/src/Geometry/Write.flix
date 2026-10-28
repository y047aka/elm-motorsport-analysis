/// The geometry file, written: the survey's places, metres and claims as the bytes the
/// app reads.
///
/// The profile is the one every reader of a kept file reads — `Geometry.flix` reads it
/// back, `Regenerate.flix` compares it property by property, the app draws it: EPSG:4326
/// throughout, as the Atlas keeps it; one `outline` LineString whose `metres` property
/// holds, point for point, how far round the lap each stands, in the circuit's published
/// metres; one `pit_lane` LineString with no metres; the `direction` the chained survey
/// runs; and the frame the degrees project through, whole, so the drawing's
/// `Circuit.Geodesy` is a copy of it and not a re-derivation. A `basis` says what kind of
/// line it is, and the ODbL copyright travels in `source` and `license`. Where the circuit
/// itself publishes the lines it times to, those authored stretches travel as `sectors`.
///
/// Coordinates, metres and every other array are written on one line each, so a kept
/// geometry is one line per property rather than one per number, and a refreshed survey
/// reads as two changed lines per feature.
///
/// This is the writing only: which answer a file was surveyed from, where it is kept, and
/// whether it is laid down at all are the `survey` word's, in `Survey.flix`. The atlas
/// reading lays a different profile — a `measured-midline` that does not end at the
/// published lap — out of this module's JSON spelling and none of its outline.
pub mod Geometry.Write {

    use Circuit.Circuit
    use Geodesy.Frame
    use Geodesy.Place

    /// The file as the app reads it: one FeatureCollection of the outline and the pit
    /// lane, in that order, the outline first because it is the line the drawing is
    /// measured along.
    pub def file(circuit: Circuit, geometry: Survey.Geometry): String =
        let outline = feature(outlineOf(circuit, geometry), lineOf(geometry#centreline));
        let pit = feature(pitOf(circuit), pitLineOf(geometry#pitLane));
        "{\"type\": \"FeatureCollection\", \"features\": [\n${outline},\n${pit}\n]}\n"

        // ---------------------------------------------------------------- the properties

    /// What the outline says it is, in the order the file says it in. A kept geometry is
    /// diffed by people as much as read by the app, so the order is the file's own, and
    /// `Regenerate` takes the order of its drift report from the same list below.
    def outlineOf(circuit: Circuit, geometry: Survey.Geometry): List[String] =
        List.map(property, List.filterMap(name -> pair(name, circuit, geometry), claims()))

    /// A property's name beside the value the outline claims for it, where it claims one.
    def pair(name: String, circuit: Circuit, geometry: Survey.Geometry): Option[(String, String)] =
        Option.map(value -> (name, value), claim(name, circuit, geometry))

    /// The properties the outline is written with, in the order the file lays them.
    /// The regeneration fence compares in this order, so a claim added to the profile
    /// is asked at its own place in a drift line.
    pub def claims(): List[String] =
        "role" :: "circuit" :: "basis" :: "source" :: "license" :: "surveyed_at" ::
        "direction" :: "lap_length_m" :: "surveyed_length_m" :: "sectors" :: "frame" ::
        "metres" :: Nil

    /// What the outline claims for one of its properties, where this geometry can say
    /// it. A claim a circuit cannot make — no stamp on the answer, no map of its own —
    /// is `None` and writes no line at all in the file, rather than a null.
    def claim(name: String, circuit: Circuit, geometry: Survey.Geometry): Option[String] =
        match name {
            case "role"              => Some(text("outline"))
            case "circuit"           => Some(text(circuit#word))
            case "basis"             => Some(centreline())
            case "source"            => Some(relation(circuit))
            case "license"           => Some(licence())
            case "surveyed_at"       => Option.map(text, geometry#surveyedAt)
            case "direction"         => Some(text(geometry#direction))
            case "lap_length_m"      => Some(number(circuit#lap))
            // The survey's own length, as the double it summed to rather than a rounded
            // reading of it: it is the figure the stretching was done with.
            case "surveyed_length_m" => Option.map(number, geometry#surveyedLength)
            case "sectors"           => Option.map(published, circuit#sectors#published)
            case "frame"             => Some(frame(geometry#frame))
            case "metres"            => Some(metres(geometry#centreline))
            // A name no `claims` lays, so a property this profile is not written with.
            case _                   => None
        }

    /// The pit lane, which claims only what every centreline claims of itself.
    def pitOf(circuit: Circuit): List[String] =
        List.map(
            property,
            ("role", text("pit_lane"))
                :: ("circuit", text(circuit#word))
                :: ("basis", centreline())
                :: ("license", licence())
                :: Nil
        )

    /// The kind of line this is: the OpenStreetMap centreline stretched to a published
    /// lap — the claim a line measured off orthoimagery must not borrow.
    def centreline(): String = text("osm-centreline")

    def relation(circuit: Circuit): String =
        text("https://www.openstreetmap.org/relation/${circuit#relation}")

    /// The copyright the survey came with; ODbL requires every drawing of it to say so too.
    def licence(): String = text("ODbL")

    /// The timing lines the circuit publishes, and the map they were copied from. A
    /// circuit whose map answers for one season only writes none.
    def published(lines: Circuit.Publishes): String =
        "{\"source\":${text(lines#source)},\"stretches\":${stretches(lines#stretches)}}"

    def stretches(distances: List[Float64]): String =
        "[${String.intercalate(",", List.map(number, distances))}]"

    /// The frame the degrees project through, whole: the drawing re-runs this projection
    /// rather than choosing one of its own. The corner is written as the survey measured
    /// it, not as a rounded box around it.
    def frame(laid: Frame): String =
        "{\"origin\":{\"lat\":${number(laid#origin#lat)},\"lon\":${number(laid#origin#lon)}},\"parallel\":${number(laid#parallel)}}"

    /// How far round the lap each place stands.
    def metres(places: List[Survey.MetredPlace]): String =
        "[${String.intercalate(",", List.map(place -> number(place#metres), places))}]"

    // ---------------------------------------------------------------- the coordinates

    /// A feature, laid out as the file lays it out: the properties one per line, the
    /// geometry on its own line and its coordinates on the one line inside that.
    def feature(props: List[String], coordinates: String): String =
        "    {\n      \"type\": \"Feature\",\n      \"properties\": {\n${String.intercalate(",\n", props)}\n      },\n      \"geometry\": ${coordinates}\n    }"

    /// The lap: degrees, lon before lat as GeoJSON gives them, the last place being the
    /// first one again because the lap closed.
    def lineOf(places: List[Survey.MetredPlace]): String =
        "{\"type\":\"LineString\",\"coordinates\":[${String.intercalate(",", List.map(each, places))}]}"

    def each(place: Survey.MetredPlace): String = "[${number(place#lon)},${number(place#lat)}]"

    /// The pit lane: degrees and nothing else.
    def pitLineOf(places: List[Place]): String =
        "{\"type\":\"LineString\",\"coordinates\":[${String.intercalate(",", List.map(eachAt, places))}]}"

    def eachAt(place: Place): String = "[${number(place#lon)},${number(place#lat)}]"

    /// One property of a feature, written as the file writes it.
    def property(pair: (String, String)): String =
        match pair {
            case (key, value) => "        ${text(key)}: ${value}"
        }

    // ------------------------------------------------------------------ the spelling

    /// A number as JSON spells it. Java keeps a decimal point where JavaScript drops it, and
    /// both print the shortest double that reads back as the same number — so a metre written
    /// here is the metre the pipeline's writer wrote, digit for digit. The two spellings part
    /// only outside the magnitudes a geometry holds: Java reaches for an exponent at ten
    /// million and below a thousandth, JavaScript at 1e21 and 1e-6.
    pub def number(value: Float64): String =
        let spelled = Float64.toString(value);
        if (String.endsWith({suffix = ".0"}, spelled)) String.dropRight(2, spelled) else spelled

    /// A word as JSON spells it: quoted, and with the characters JSON cannot carry inside
    /// a string written as what they are.
    pub def text(spelled: String): String = "\"${escaped(spelled)}\""

    def escaped(spelled: String): String =
        List.foldLeft((held, letter) -> held + escape(letter), "", String.toList(spelled))

    def escape(letter: Char): String =
        match letter {
            case '"'  => "\\\""
            case '\\' => "\\\\"
            case '\n' => "\\n"
            case '\r' => "\\r"
            case '\t' => "\\t"
            case _    => "${letter}"
        }
}
