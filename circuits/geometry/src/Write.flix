/// The geometry file, written: the survey's places, metres and claims as the bytes the
/// app reads.
///
///     nix run .#geometry-survey -- cota
///     nix run .#geometry-survey -- cota --write
///     nix run .#geometry-survey -- le_mans --answer circuits/le_mans/overpass.json
///
/// The profile is the one every reader of a kept file reads: EPSG:4326 throughout, as
/// the Atlas keeps it; one `outline` LineString whose `metres` property holds, point for
/// point, how far round the lap each stands, in the circuit's published metres; one
/// `pit_lane` LineString with no metres because nothing times along it; the `direction`
/// the chained survey runs; and the frame the degrees project through, whole, so the
/// drawing's `Circuit.Geodesy` is a copy of it and not a re-derivation. A `basis` says
/// what kind of line it is, and the ODbL copyright travels in `source` and `license`.
/// Where the circuit itself publishes the lines it times to, those authored stretches
/// travel as `sectors`, so a check of the timing lines reads data rather than a config.
///
/// Coordinates, metres and every other array are written on one line each, so a kept
/// geometry is one line per property rather than one per number, and a refreshed survey
/// reads as two changed lines per feature.
///
/// A run without `--write` changes nothing and answers one question: does the survey over
/// the kept answer still draw the bytes the app serves? The fence over every circuit at once
/// is `circuits/regenerate-geometry.ts`'s, and compares parsed properties with `surveyed_at`
/// exempt; this comparison is of bytes, and `surveyed_at` needs no exemption here because
/// the survey reads the very answer whose stamp the property carries.
pub mod Write {

    use Circuit.Circuit
    use Geometry.Place
    use Sys.Console

    /// The file as the app reads it: one FeatureCollection of the outline and the pit
    /// lane, in that order, the outline first because it is the line the drawing is
    /// measured along.
    pub def geoJson(circuit: Circuit, geometry: Survey.Geometry): String =
        let outline = feature(outlineOf(circuit, geometry), lineOf(geometry#centreline));
        let pit = feature(pitOf(circuit), pitLineOf(geometry#pitLane));
        "{\"type\": \"FeatureCollection\", \"features\": [\n${outline},\n${pit}\n]}\n"

        // ---------------------------------------------------------------- the properties

    /// What the outline says it is, in the order the file says it in. The order is the
    /// file's own: a kept geometry is read by people diffing it as much as by the app,
    /// and a property that moved down the list is a diff that says nothing about the
    /// survey.
    def outlineOf(circuit: Circuit, geometry: Survey.Geometry): List[String] =
        List.map(property, List.flatMap(present, authored(circuit, geometry)))

    /// What the outline claims, in the order it claims it. A claim a circuit cannot make
    /// — no stamp on the answer, no map of its own — is `None` here and no line at all in
    /// the file, which is what every reader of a kept geometry asks for.
    def authored(circuit: Circuit, geometry: Survey.Geometry): List[Option[(String, String)]] =
        Some(("role", text("outline")))
            :: Some(("circuit", text(circuit#word)))
            :: Some(("basis", centreline()))
            :: Some(("source", relation(circuit)))
            :: Some(("license", licence()))
            :: Option.map(stamped -> ("surveyed_at", text(stamped)), geometry#surveyedAt)
            :: Some(("direction", text(geometry#direction)))
            :: Some(("lap_length_m", number(circuit#lap)))
            // The survey's own length, as the double it summed to rather than a rounded
            // reading of it: it is the figure the stretching was done with.
            :: Option.map(length -> ("surveyed_length_m", number(length)), geometry#surveyedLength)
            :: Option.map(lines -> ("sectors", published(lines)), circuit#sectors#published)
            :: Some(("frame", frame(geometry#frame)))
            :: Some(("metres", metres(geometry#centreline)))
            :: Nil

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
    /// lap, which is what a line measured off orthoimagery would say it is not.
    def centreline(): String = text("osm-centreline")

    def relation(circuit: Circuit): String =
        text("https://www.openstreetmap.org/relation/${circuit#relation}")

    /// The copyright the survey came with, which is why the file says it and why every
    /// drawing of it has to say it too.
    def licence(): String = text("ODbL")

    /// The timing lines the circuit publishes, and the map they were copied from. A
    /// circuit whose map answers for one season only writes none, so that a reader of the
    /// file is never handed one season's lines as though they served every one.
    def published(lines: Circuit.Publishes): String =
        "{\"source\":${text(lines#source)},\"stretches\":${stretches(lines#stretches)}}"

    def stretches(distances: List[Float64]): String =
        "[${String.intercalate(",", List.map(number, distances))}]"

    /// The frame the degrees project through, whole: the drawing re-runs this projection
    /// rather than choosing one of its own, which is why the corner is written as the
    /// survey measured it and not as a rounded box around it.
    def frame(laid: Survey.Frame): String =
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

    /// The pit lane: degrees and nothing else, because nothing times along it.
    def pitLineOf(places: List[Place]): String =
        "{\"type\":\"LineString\",\"coordinates\":[${String.intercalate(",", List.map(eachAt, places))}]}"

    def eachAt(place: Place): String = "[${number(place#lon)},${number(place#lat)}]"

    /// One property of a feature, written as the file writes it.
    def property(pair: (String, String)): String =
        match pair {
            case (key, value) => "        ${text(key)}: ${value}"
        }

    /// A property that is there. An absent one writes no line at all rather than a null,
    /// which is what every reader of a kept geometry asks for.
    def present(entry: Option[(String, String)]): List[(String, String)] = Option.toList(entry)

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

    // ------------------------------------------------------------------- the command

    /// One circuit, the answer it is surveyed from, and whether the file is laid down.
    /// `asked` says whether the answer was named on the command line or taken from the
    /// circuit's directory, which is what tells a missing survey from an unreadable one.
    pub type alias Args = {
        circuit = Circuit,
        answer  = String,
        asked   = Bool,
        write   = Bool
    }

    pub def parse(args: List[String]): Result[String, Args] =
        walked(Nil, args, None, false)

    def walked(named: List[String], rest: List[String], answer: Option[String], write: Bool): Result[String, Args] =
        match rest {
            case Nil => complete(named, answer, write)
            case "--answer" :: path :: further =>
                // A flag is no file: `--answer --write` is a reader who meant something
                // else, and a survey that read it as a path would report a file that cannot
                // be opened rather than an argument it was not given.
                if (String.startsWith({prefix = "--"}, path)) Err("--answer names no file to read")
                else walked(named, further, Some(path), write)
            case "--answer" :: Nil => Err("--answer names no file to read")
            case "--write" :: further => walked(named, further, answer, true)
            case one :: further =>
                if (String.startsWith({prefix = "--"}, one)) Err("\"${one}\" is no flag of this command")
                else walked(one :: named, further, answer, write)
        }

    def complete(named: List[String], answer: Option[String], write: Bool): Result[String, Args] =
        match named {
            case Nil => Err(usage())
            case one :: _ =>
                match Circuit.byWord(one) {
                    case None => Err(Circuit.unknown(one))
                    case Some(circuit) =>
                        Ok({
                            circuit = circuit,
                            answer = Option.getWithDefault(Circuit.keptAnswer(circuit), answer),
                            asked = Option.nonEmpty(answer),
                            write = write
                        })
                }
        }

    pub def usage(): String =
        "usage: nix run .#geometry-survey -- <circuit> [--answer <overpass.json>] [--write]"

    /// The exit code the survey comes to: 1 for a word no circuit answers to, an answer it
    /// was pointed at and cannot read, a survey it could not chain, and a file it could not
    /// write.
    pub def exitCode(args: List[String]): Int32 \ { IO, Console } =
        match parse(args) {
            case Err(problem) =>
                Console.eprintln("${problem}");
                1
            case Ok(asked) => ask(asked)
        }

    def ask(asked: Args): Int32 \ { IO, Console } =
        match Util.Files.read(asked#answer) {
            case Err(_) =>
                if (asked#asked)
                    answerMissing(asked)
                else
                    noSurvey(asked)
            case Ok(spelled) => surveyed(asked, spelled)
        }

    def answerMissing(asked: Args): Int32 \ Console = {
        Console.eprintln("${asked#answer}: no answer to read there");
        1
    }

    /// A circuit with no kept answer has not been surveyed yet, which is not a failure of
    /// a run over every circuit: asking OpenStreetMap is the other command's, and says so
    /// from where the asking happens.
    def noSurvey(asked: Args): Int32 \ Console = {
        Console.println("${asked#circuit#word}: no kept answer yet — asking OpenStreetMap is `nix run .#geometry-write`'s");
        0
    }

    def surveyed(asked: Args, spelled: String): Int32 \ { IO, Console } =
        match Survey.answer(spelled) {
            case Err(problem) =>
                Console.eprintln("${asked#answer}: ${problem}");
                1
            case Ok(reading) =>
                match Survey.lapOf(reading, asked#circuit) {
                    case Err(problem) =>
                        Console.eprintln("${asked#circuit#word}: ${problem}");
                        1
                    case Ok(geometry) => laid(asked, geoJson(asked#circuit, geometry))
                }
        }

    /// The file laid down, or the kept one asked for and laid against what the survey
    /// draws.
    def laid(asked: Args, written: String): Int32 \ { IO, Console } =
        if (asked#write)
            laidDown(asked, written)
        else
            match Util.Files.read(asked#circuit#file) {
                case Err(_) =>
                    Console.eprintln("${asked#circuit#file}: no geometry to compare against — --write lays one");
                    1
                case Ok(kept) => against(asked, written, kept)
            }

    def laidDown(asked: Args, written: String): Int32 \ { IO, Console } =
        match Util.Files.write(asked#circuit#file, written) {
            case Err(problem) =>
                Console.eprintln("${asked#circuit#file}: ${problem}");
                1
            case Ok(_) =>
                Console.println("${asked#circuit#word}: geometry written from ${asked#answer}");
                0
        }

    def against(asked: Args, written: String, kept: String): Int32 \ Console =
        if (written == kept)
            reproduces(asked)
        else
            drifted(asked, written, kept)

    def reproduces(asked: Args): Int32 \ Console = {
        Console.println("${asked#circuit#word}: reproduces the kept geometry, every point and metre of it");
        0
    }

    def drifted(asked: Args, written: String, kept: String): Int32 \ Console = {
        Console.println("${asked#circuit#word}: the kept geometry is not what the kept answer draws");
        Console.println("  ${firstPart(written, kept)}");
        1
    }

    /// Where two files part: the line they part at, and what each of them says there, cut
    /// short — a metre that moved is found by where it moved, not by the digits around it.
    pub def firstPart(written: String, kept: String): String =
        parted(String.lines(written), String.lines(kept), 1)

    def parted(written: List[String], kept: List[String], at: Int32): String =
        match (written, kept) {
            case (one :: more, only :: rest) =>
                if (one == only) parted(more, rest, at + 1) else partedAt(at, one, only)
            case (Nil, Nil) => "the two files are the same bytes after all"
            case _ => "the files part at line ${at}, where one of them has nothing left"
        }

    def partedAt(at: Int32, written: String, kept: String): String =
        "line ${at} is ${shown(kept)} in the file, ${shown(written)} from the answer"

    /// A line of a file as far as it is worth reading.
    pub def shown(line: String): String = {
        let cut = 100;
        let body = String.take(cut, line);
        let ends = if (String.length(line) > cut) "…" else "";
        "\"${String.trim(body)}${ends}\""
    }
}
