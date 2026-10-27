/// The geometry file, written: the survey's places, metres and claims as the bytes the
/// app reads.
///
///     nix run .#geometry -- survey cota
///     nix run .#geometry -- survey cota --write
///     nix run .#geometry -- survey le_mans --answer circuits/le_mans/overpass.json
///     nix run .#geometry -- survey cota --fetch
///
/// The profile is the one every reader of a kept file reads: EPSG:4326 throughout, as
/// the Atlas keeps it; one `outline` LineString whose `metres` property holds, point for
/// point, how far round the lap each stands, in the circuit's published metres; one
/// `pit_lane` LineString with no metres; the `direction` the chained survey runs; and
/// the frame the degrees project through, whole, so the drawing's `Circuit.Geodesy` is
/// a copy of it and not a re-derivation. A `basis` says what kind of line it is, and the
/// ODbL copyright travels in `source` and `license`. Where the circuit itself publishes
/// the lines it times to, those authored stretches travel as `sectors`.
///
/// Coordinates, metres and every other array are written on one line each, so a kept
/// geometry is one line per property rather than one per number, and a refreshed survey
/// reads as two changed lines per feature.
///
/// A run without `--write` changes nothing and answers one question: does the survey over
/// the kept answer still draw the bytes the app serves? The fence over every circuit at once
/// is `Regenerate.flix`'s, and compares parsed properties with `surveyed_at`
/// exempt; this comparison is of bytes, and the byte comparison reads the very answer
/// whose stamp the property carries, so it has nothing to exempt.
///
/// `--fetch` is the network raised as a flag rather than as a command word: the run
/// asks OpenStreetMap now, keeps the answer where `--answer` points — the circuit's own
/// directory when it names none — and travels on through exactly the `surveyed` a kept
/// answer travels through, so a live run and a run over a kept file fail and reproduce
/// in the same words. Keeping an answer is `--fetch`'s alone and laying the geometry is
/// `--write`'s alone; a `--fetch` without `--write` keeps the evidence and then answers,
/// without laying anything down, whether the fresh survey moves the served bytes.
pub mod Write {

    use Circuit.Circuit
    use Cli.Args.ArgsError
    use Cli.Args.Outcome
    use Geometry.Place
    use Sys.Console
    use Time.Clock
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    /// The file as the app reads it: one FeatureCollection of the outline and the pit
    /// lane, in that order, the outline first because it is the line the drawing is
    /// measured along.
    pub def geoJson(circuit: Circuit, geometry: Survey.Geometry): String =
        let outline = feature(outlineOf(circuit, geometry), lineOf(geometry#centreline));
        let pit = feature(pitOf(circuit), pitLineOf(geometry#pitLane));
        "{\"type\": \"FeatureCollection\", \"features\": [\n${outline},\n${pit}\n]}\n"

        // ---------------------------------------------------------------- the properties

    /// What the outline says it is, in the order the file says it in. A kept geometry is
    /// diffed by people as much as read by the app, so the order is the file's own.
    def outlineOf(circuit: Circuit, geometry: Survey.Geometry): List[String] =
        List.map(property, List.flatMap(present, authored(circuit, geometry)))

    /// What the outline claims, in the order it claims it. A claim a circuit cannot make
    /// — no stamp on the answer, no map of its own — writes no line at all in the file.
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

    /// The pit lane: degrees and nothing else.
    def pitLineOf(places: List[Place]): String =
        "{\"type\":\"LineString\",\"coordinates\":[${String.intercalate(",", List.map(eachAt, places))}]}"

    def eachAt(place: Place): String = "[${number(place#lon)},${number(place#lat)}]"

    /// One property of a feature, written as the file writes it.
    def property(pair: (String, String)): String =
        match pair {
            case (key, value) => "        ${text(key)}: ${value}"
        }

    /// A property that is there. An absent one writes no line at all rather than a null.
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
        fetch   = Bool,
        write   = Bool
    }

    pub def parse(args: List[String]): Result[ArgsError, Args] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  => completed(scanned)
        }

    def completed(scanned: Cli.Args.Scanned[Setting]): Result[ArgsError, Args] =
        complete(
            scanned#words,
            Cli.Args.lastNamed(answerNamed, scanned#options),
            List.exists(isFetched, scanned#options),
            List.exists(isWritten, scanned#options)
        )

    enum Setting with Eq {
        case Answer(String)
        case Fetch
        case Help
        case Written
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
        Cli.Args.helpDescr(Setting.Help) ::
        {
            optionIds     = Nil,
            optionNames   = "answer" :: Nil,
            argDescriptor = ArgDescr.ReqArg(path -> Some(Setting.Answer(path)), "OVERPASS.JSON"),
            explanation   = "survey the answer kept here instead of the circuit's own"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "fetch" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.Fetch),
            explanation   = "ask OpenStreetMap now and keep the answer at --answer\nor beside the circuit instead of reading the kept one"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "write" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.Written),
            explanation   = "lay the geometry file down instead of answering whether\nthe survey still draws the kept bytes"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    /// A flag is no file: `--answer --write` is a reader who meant something else,
    /// and a survey that read it as a path would report a file that cannot be
    /// opened rather than an argument it was not given. GetOpt hands the argument
    /// over as it came; it is the completing that refuses one.
    def complete(named: List[String], answer: Option[String], fetch: Bool, write: Bool): Result[ArgsError, Args] =
        match answer {
            case Some(path) if Cli.Args.isFlag(path) =>
                Err(ArgsError.ParseErrors("--answer names no file to read" :: Nil))
            case _ =>
                match named {
                    case Nil => Err(ArgsError.ParseErrors("survey reads one circuit." :: Nil))
                    case one :: _ =>
                        match Circuit.byWord(one) {
                            case None => Err(ArgsError.ParseErrors(Circuit.unknown(one) :: Nil))
                            case Some(circuit) =>
                                Ok({
                                    circuit = circuit,
                                    answer = Option.getWithDefault(Circuit.keptAnswer(circuit), answer),
                                    asked = Option.nonEmpty(answer),
                                    fetch = fetch,
                                    write = write
                                })
                        }
                }
        }

    def answerNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.Answer(path) => Some(path)
            case _                    => None
        }

    def isFetched(setting: Setting): Bool =
        match setting {
            case Setting.Fetch => true
            case _             => false
        }

    def isWritten(setting: Setting): Bool =
        match setting {
            case Setting.Written => true
            case _               => false
        }

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "usage: nix run .#geometry -- survey <circuit> [--answer <overpass.json>] [--fetch] [--write]",
            optionDescrs()
        )

    /// The exit code the survey comes to: `--help` and a wrong argument are answered
    /// out of the flag table, and everything else by the readings below — an answer
    /// that is not there, a survey that would not chain, a file that would not write.
    pub def exitCode(args: List[String]): Int32 \ { IO, Clock, Console } =
        Cli.Args.comeTo(arguments(args), asking)

    /// The arguments as far as the flag table reads them, before this module asks
    /// which circuit a word answers to.
    pub def arguments(args: List[String]): Cli.Args.Parsed[Args] =
        Cli.Args.prepare(optionDescrs(), usage(), isHelp, completed, args)

    /// The asking: the answer read — from a runner, from the file `--answer` names,
    /// or from the answer the circuit keeps — surveyed once, kept where a runner gave
    /// it, and then laid or compared however `--write` says.
    pub def asking(asked: Args): Outcome \ { IO, Clock, Console } =
        match answerText(asked) {
            case Err(problem)      => Outcome.Failed(problem)
            case Ok(None)          => Outcome.Done(neverSurveyed(asked) :: Nil)
            case Ok(Some(spelled)) =>
                Cli.Args.outcomeOf(
                    forM(
                        read <- surveyed(asked, spelled);
                        _    <- if (asked#fetch) kept(asked, read) else Ok(())
                    ) yield laid(asked, Write.geoJson(asked#circuit, read#geometry))
                )
        }

    /// Where a run's answer comes from. Finding nothing is the one reading with two
    /// right answers, which is why it comes back as `None` and not as a failure:
    /// `--answer` naming nothing is a mistake to report, while a circuit with no kept
    /// answer and no served geometry has simply never been surveyed.
    def answerText(asked: Args): Result[String, Option[String]] \ { IO, Clock } =
        if (asked#fetch)
            Overpass.askRelation(asked#circuit#relation)
                |> Result.mapErr(problem -> "${asked#circuit#word}: ${problem}")
                |> Result.map(spelled -> Some(spelled))
        else
            match Util.Files.read(asked#answer) {
                case Ok(spelled) => Ok(Some(spelled))
                case Err(_) =>
                    if (asked#asked)
                        Err("${asked#answer}: no answer to read there")
                    else
                        unexamined(asked)
            }

    /// Which of the two a circuit with no answer to read is. A served file says the
    /// bytes have no answer left to re-survey them from — which is what the fence
    /// exists to catch — and no served file says nobody has surveyed this circuit yet.
    def unexamined(asked: Args): Result[String, Option[String]] \ IO =
        match Util.Files.read(asked#circuit#file) {
            case Ok(_)  => Err("${asked#circuit#word}: ${asked#circuit#file} is served but ${asked#answer} is not kept — these bytes have no answer left to re-survey them from")
            case Err(_) => Ok(None)
        }

    def neverSurveyed(asked: Args): String =
        "${asked#circuit#word}: no kept answer yet — asking OpenStreetMap is `--fetch`'s"

    /// An answer read and surveyed: the text `--fetch` keeps, the answer it is kept
    /// with, and the geometry the file is written from.
    type alias Read = {
        text     = String,
        answer   = Survey.Answer,
        geometry = Survey.Geometry
    }

    /// The survey every answer travels through, however its text arrived, which is
    /// what makes a live survey and a comparison of a kept one fail and reproduce in
    /// the same words. One reading of the text serves both the keeping and the
    /// laying, so a runner's HTML page, a reply stopped half way through its JSON and
    /// an answer whose relation will not chain into a lap are each met in the words
    /// the survey itself would say them in, rather than in a file kept to be
    /// discovered later.
    def surveyed(asked: Args, spelled: String): Result[String, Read] =
        match surveyable(spelled, asked#circuit) {
            case Ok((answer, geometry)) => Ok({text = spelled, answer = answer, geometry = geometry})
            case Err(problem) =>
                if (asked#fetch)
                    Err("${asked#answer}: the answer surveys nothing: ${problem}")
                else
                    Err("${asked#answer}: ${problem}")
        }

    /// Whether this text is an answer the survey can read: the JSON, the circuit's
    /// relation, the chained lap and the line the circuit says that lap starts at —
    /// everything the kept file will be re-read for, asked before a byte is kept.
    pub def surveyable(spelled: String, circuit: Circuit): Result[String, (Survey.Answer, Survey.Geometry)] =
        Survey.survey(spelled, circuit)

    /// `--fetch`'s keeping: the answer where `--answer` points — the circuit's own
    /// directory when it names none — and the line naming how big an answer it is. It
    /// is asked once the survey has read the text and before anything is laid, since
    /// an answer that surveys nothing is evidence nobody can re-run.
    def kept(asked: Args, read: Read): Result[String, Unit] \ { IO, Console } =
        match Cli.Errors.writeFile(asked#answer, read#text) {
            case Err(problem) => Err("${problem}")
            case Ok(_) =>
                Console.println(keptLine(asked, read#answer));
                Ok(())
        }

    /// What the asking left beside the circuit.
    def keptLine(asked: Args, reading: Survey.Answer): String =
        let elements = Int32.toString(List.length(reading#elements));
        let stamp = match reading#surveyedAt {
            case None     => ""
            case Some(at) => ", surveyed at ${at}"
        };
        "${asked#circuit#word}: kept an answer of ${elements} elements${stamp} at ${asked#answer}"

    /// The file laid down, or the kept one asked for and laid against what the survey
    /// draws.
    def laid(asked: Args, written: String): Outcome \ IO =
        if (asked#write)
            laidDown(asked, written)
        else
            match Util.Files.read(asked#circuit#file) {
                case Err(_)    => Outcome.Failed("${asked#circuit#file}: no geometry to compare against — --write lays one")
                case Ok(served) => against(asked, written, served)
            }

    def laidDown(asked: Args, written: String): Outcome \ IO =
        match Cli.Errors.writeFile(asked#circuit#file, written) {
            case Err(problem) => Outcome.Failed("${problem}")
            case Ok(_)        => Outcome.Done("${asked#circuit#word}: geometry written from ${asked#answer}" :: Nil)
        }

    /// Whether the bytes the survey draws are the bytes the app serves. That they are
    /// not is the answer the run was asked for rather than a run that failed, so it is
    /// said on stdout and exits 1.
    def against(asked: Args, written: String, served: String): Outcome =
        if (written == served)
            Outcome.Done("${asked#circuit#word}: reproduces the kept geometry, every point and metre of it" :: Nil)
        else
            Outcome.Verdict(
                "${asked#circuit#word}: the kept geometry is not what the kept answer draws"
                    :: "  ${firstPart(written, served)}"
                    :: Nil
            )

    /// Where two files part: the line they part at, and what each of them says there, cut
    /// short.
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
