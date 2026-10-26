/// Reads one circuit's measured line out of the track-atlas dataset — its outline's
/// edges are measured off orthoimagery registered to lidar, with OpenStreetMap's
/// centreline fixing the lap order, origin and direction — and keeps it in this
/// repository's geometry profile, at the atlas length and *not* stretched.
///
///     nix run .#geometry -- atlas <circuit> [--file gp.geojson]
///
/// A circuit joins the reading by carrying an `atlas` entry naming the track-atlas layer
/// for the layout this app draws; a circuit without one is asked nothing. It prints the
/// four readings that matter before anyone draws on them: how far the lines stand apart
/// in metres; whether the atlas corner markers land at the lap distances this app's
/// geometry puts them at; whether the atlas pit entry and exit stand on the pit lane
/// that geometry chains out of the relation; and where the circuit's own published
/// sector lines stand on each of the two lines.
///
/// The lap-origin guard is asked of the measured line's start before anything is kept.
/// The apartness math is `Apart`'s, shared with the diff; the feature shape checks, the
/// guards and the written file are `Track`'s. This file adds only the measuring.
///
/// The atlas data is © its contributors under the ODbL, itself derived from OpenStreetMap
/// and open orthoimagery; the written file carries the source URL beside the license.
pub mod Atlas {

    use Circuit.Circuit
    use Cli.Args.ArgsError
    use Geometry.Place
    use IoError.IoError
    use Net.HttpRequest.HttpRequest
    use Net.Https.Https
    use Sys.Console
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr
    use Util.Json.Json

    /// What a run calls itself at the atlas's home. Not the Overpass user agent: this
    /// asks a dataset's repository, not a live map's service, once and without retries.
    pub def userAgent(): String = "elm-motorsport-analysis/1.0 (atlas geometry)"

    /// Where a run keeps what it read: the atlas line beside the config, at its own
    /// length, and every reading the report prints.
    type alias Reading = {
        circuit     = Circuit,
        source      = String,
        coords      = List[Place],
        corners     = List[Track.Feature],
        pits        = List[Track.Feature],
        theirMetres = List[Float64],
        origin      = Float64,
        deviation   = Apart.Apartness,
        atCorners   = List[AtCorner],
        atPits      = List[AtPit],
        pitLength   = Float64,
        atLines     = List[AtLine],
        sectors     = Option[Track.Sectors]
    }

    type alias AtCorner = {
        id          = String,
        theirMetres = Float64,
        ourMetres   = Float64,
        distance    = Float64
    }

    type alias AtPit = {
        role        = String,
        theirMetres = Float64,
        along       = Float64,
        distance    = Float64
    }

    type alias AtLine = {
        id          = String,
        metres      = Float64,
        theirMetres = Float64,
        distance    = Float64
    }

    /// The kept geometry read beside the config: the line the app draws, its own
    /// metres, the pit lane the atlas pit markers are placed against, and the outline's
    /// properties as they stand — the sectors claim is read off them by
    /// `Track.sectorsClaimed`, which is where a half-claim reads as no claim.
    type alias Kept = {
        coords = List[Place],
        metres = List[Float64],
        pit    = List[Place],
        props  = Map[String, Json]
    }

    // ------------------------------------------------------------------- the command

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "usage: nix run .#geometry -- atlas <circuit> [--file <atlas.geojson>]",
            optionDescrs()
        )

    enum Setting with Eq {
        case Help
        case File(String)
    }

    /// `--file <path>`, and nothing else a run does not know. One run reads one layer.
    def optionDescrs(): List[OptionDescr[Setting]] =
        Cli.Args.helpDescr(Setting.Help) ::
        {
            optionIds     = Nil,
            optionNames   = "file" :: Nil,
            argDescriptor = ArgDescr.ReqArg(path -> Some(Setting.File(path)), "ATLAS.GEOJSON"),
            explanation   = "read this kept layer instead of fetching the circuit's own"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    /// The exit code the reading comes to: 1 for a word no circuit answers to, a
    /// circuit with no atlas layer, a file that would not read or a line that failed a
    /// guard, and 0 once the line is measured and kept.
    pub def exitCode(args: List[String]): Int32 \ { IO, Console } =
        Net.Https.runWithIO(
            () ->
                Cli.Args.answer(
                    optionDescrs(),
                    usage(),
                    isHelp,
                    args,
                    scanned -> readOf(scanned#words, Cli.Args.lastNamed(fileNamed, scanned#options)),
                    measuredReport
                )
        )

    def measuredReport(circuitAndFile: (Circuit, Option[String])): Int32 \ { IO, Console, Https } =
        match circuitAndFile {
            case (circuit, file) =>
                match measure(circuit, file) {
                    case Err(problem) =>
                        Console.eprintln(problem);
                        1
                    case Ok(reading) =>
                        report(reading);
                        0
                }
        }

    /// The circuit to read, and the layer to read it from: the file named, or the
    /// circuit's own layer fetched when no file is given.
    pub def asked(args: List[String]): Result[ArgsError, (Circuit, Option[String])] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  =>
                readOf(scanned#words, Cli.Args.lastNamed(fileNamed, scanned#options))
        }

    /// A flag is no file, as at the other commands: a run that read `--file --write`
    /// as a path would keep one circuit's evidence under a name no file can be
    /// called.
    def readOf(words: List[String], file: Option[String]): Result[ArgsError, (Circuit, Option[String])] =
        match words {
            case Nil => Err(ArgsError.ParseErrors("atlas reads one circuit." :: Nil))
            case one :: extra =>
                if (not List.isEmpty(extra))
                    Err(ArgsError.UnexpectedArguments(extra))
                else
                    match Circuit.byWord(one) {
                        case None => Err(ArgsError.ParseErrors(Circuit.unknown(one) :: Nil))
                        case Some(circuit) =>
                            match circuit#atlas {
                                case None =>
                                    Err(ArgsError.ParseErrors("${one}'s config names no atlas layer to read" :: Nil))
                                case Some(_) =>
                                    if (Option.exists(Cli.Args.isFlag, file))
                                        Err(ArgsError.ParseErrors("--file names no file to read" :: Nil))
                                    else
                                        Ok((circuit, file))
                            }
                    }
        }

    def fileNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.File(path) => Some(path)
            case _                  => None
        }

    // ------------------------------------------------------------------ the measuring

    /// The layer read — the named file, or the circuit's own asked for now — measured
    /// against the geometry the app serves, and kept beside the config. The guards all
    /// answer before anything is written: a line that is another circuit's, or starts at
    /// another line, never reaches disk.
    def measure(circuit: Circuit, file: Option[String]): Result[String, Reading] \ { IO, Https } =
        match read(file, circuit) {
            case Err(problem) => Err(problem)
            case Ok(text) =>
                match layerOf(text, circuit#word) {
                    case Err(problem) => Err(problem)
                    case Ok((outline, corners, pits)) =>
                        match placesOf(corners ++ pits) {
                            case Err(problem) => Err(problem)
                            case Ok(markers) =>
                                match kept(circuit) {
                                    case Err(problem) => Err(problem)
                                    case Ok(ours) => measured(circuit, Option.getWithDefault("", circuit#atlas), outline, corners, pits, markers, ours)
                                }
                        }
                }
        }

    /// The layer's text, from the named file or from its home. The source the kept
    /// file claims is the circuit's atlas URL either way: a reading from a kept file
    /// re-keeps the line the URL's survey measured, and a file path would credit the
    /// line to whomever saved it last.
    def read(file: Option[String], circuit: Circuit): Result[String, String] \ { IO, Https } =
        match circuit#atlas {
            case None => Err("${circuit#word}'s config names no atlas layer to read")
            case Some(url) =>
                match file {
                    case Some(path) =>
                        Cli.Errors.readFile(path) |>
                            Result.mapErr(problem -> "${problem}")
                    case None => ask(url)
                }
        }

    /// The layer asked of its home: once, without retries — a dataset's repository is
    /// not a busy map, and a run that missed it can be run again. That it is JSON is
    /// asked here rather than left to a parse far from its cause.
    def ask(url: String): Result[String, String] \ Https =
        match Https.send(getting(url)) {
            case Err(error) => Err(worded(error))
            case Ok(response) =>
                if (not Net.HttpResponse.isSuccess(response))
                    Err("the atlas answered ${Net.HttpResponse.status(response)} for ${url}")
                else
                    match Util.Json.parse(Net.HttpResponse.body(response)) {
                        case Err(problem) => Err("${url} answered with something that is not JSON: ${problem}")
                        case Ok(_)        => Ok(Net.HttpResponse.body(response))
                    }
        }

    def getting(url: String): HttpRequest =
        HttpRequest.withHeader("User-Agent", userAgent(), HttpRequest.get(url))

    /// A transport failure as the report prints it: which kind, and what the client
    /// said about it.
    def worded(error: IoError): String =
        match error {
            case IoError(kind, message) => "${kind}: ${message}"
        }

    /// The layer read down to its three kinds of feature: the outline that is the line,
    /// the corners, and whichever pit markers the layer holds. The identity guard is
    /// asked here, at the first reading of the file: a file measured from another
    /// circuit replaces one circuit's kept evidence with another's, and does it quietly.
    def layerOf(text: String, slug: String): Result[String, (Track.Feature, List[Track.Feature], List[Track.Feature])] =
        match Util.Json.parse(text) {
            case Err(problem) => Err("the atlas file does not parse: ${problem}")
            case Ok(json) =>
                let features = Track.featuresOf(json);
                match List.find(feature -> Track.roleOf(feature) == Some("outline"), features) {
                    case None => Err("the atlas file holds no outline feature")
                    case Some(outline) =>
                        match Track.checkIdentity(Geometry.word("circuit", Geometry.propertiesOf(outline)), slug) {
                            case Err(problem) => Err(problem)
                            case Ok(_)        => Ok((outline, cornersOf(features), pitsOf(features)))
                        }
                }
        }

    def cornersOf(features: List[Track.Feature]): List[Track.Feature] =
        List.filter(feature -> Track.roleOf(feature) == Some("corner"), features)

    /// The pit markers, one per role, entry before exit: what a layer holds under a
    /// role twice is one entry and one exit to this reading, in the order a pit lane
    /// is driven rather than the order a file happens to hold.
    def pitsOf(features: List[Track.Feature]): List[Track.Feature] =
        List.filterMap(
            role -> List.find(feature -> Track.roleOf(feature) == Some(role), features),
            "pit_entry" :: "pit_exit" :: Nil
        )

    /// The markers' places, asked before any measuring: a marker that carries no point
    /// fails the run rather than joining the mean as a nought.
    def placesOf(markers: List[Track.Feature]): Result[String, List[Place]] =
        List.foldRight(
            (feature, places) -> match (Track.placeOf(feature), places) {
                case (Ok(one), Ok(many)) => Ok(one :: many)
                case (Err(problem), _)   => Err(problem)
                case (_, Err(problem))   => Err(problem)
            },
            Ok(Nil),
            markers
        )

    /// The kept geometry read beside the config.
    def kept(circuit: Circuit): Result[String, Kept] \ IO =
        match Cli.Errors.readFile(circuit#file) {
            case Err(problem) => Err("${problem}")
            case Ok(text) =>
                match (Geometry.outline(text, circuit#word), Geometry.pitLane(text, circuit#word)) {
                    case (Ok(outline), Ok(pit)) =>
                        Ok({coords = outline#coords, metres = outline#metres, pit = pit, props = claimed(text)})
                    case (Err(problem), _) => Err(problem)
                    case (_, Err(problem)) => Err(problem)
                }
        }

    /// The outline's properties as they stand, from the same text the line was read
    /// from. A file with no outline claims nothing — which is also what a file that
    /// does not parse claims, and both refusals are `Geometry`'s to have said first.
    def claimed(text: String): Map[String, Json] =
        match Util.Json.parse(text) {
            case Err(_)   => Map.empty()
            case Ok(json) =>
                match List.find(feature -> Geometry.word("role", Geometry.propertiesOf(feature)) == Some("outline"), Geometry.featuresOf(json)) {
                    case Some(feature) => Geometry.propertiesOf(feature)
                    case None          => Map.empty()
                }
        }

    /// The line measured: both lines laid on one parallel, the guards answered, every
    /// marker placed on this app's line, and the whole kept at last — the file is the
    /// only side effect of a run, and it happens once nothing has refused.
    def measured(
        circuit: Circuit,
        source: String,
        outline: Track.Feature,
        corners: List[Track.Feature],
        pits: List[Track.Feature],
        markers: List[Place],
        ours: Kept
    ): Result[String, Reading] \ IO =
        match Track.lineOf(outline) {
            case Err(problem) => Err(problem)
            case Ok(coords) => laid(circuit, source, coords, corners, pits, markers, ours)
        }

    /// Both lines on one plane, and every reading taken on it. The projection is laid
    /// over the two lines and all the markers together, so neither line is drawn at a
    /// scale of its own.
    def laid(
        circuit: Circuit,
        source: String,
        coords: List[Place],
        corners: List[Track.Feature],
        pits: List[Track.Feature],
        markers: List[Place],
        ours: Kept
    ): Result[String, Reading] \ IO = {
        let parallel = Apart.parallelOf(coords ++ ours#coords ++ ours#pit ++ markers);
        let onto = place -> Apart.projectOn(parallel, place);
        let theirPoints = List.map(onto, coords);
        let ourPoints = List.map(onto, ours#coords);
        let theirMetres = Survey.cumulative(theirPoints);
        let pitPoints = List.map(onto, ours#pit);
        let pitMetres = Survey.cumulative(pitPoints);
        let length = Option.getWithDefault(0.0, List.last(theirMetres));
        let first = Option.getWithDefault({lon = 0.0, lat = 0.0}, List.head(coords));
        match (
            Track.checkOrigin(first, circuit#timingLine),
            Apart.apartness(theirPoints, theirMetres, ourPoints, ours#metres, Apart.defaultEvery())
        ) {
            case (Err(problem), _) => Err(problem)
            case (_, Err(problem)) => Err(problem)
            case (Ok(origin), Ok(deviation)) =>
                match atCorners(corners, parallel, ourPoints, ours#metres, length) {
                    case Err(problem) => Err(problem)
                    case Ok(whereCorners) =>
                        match atPublished(circuit, ours, theirPoints, theirMetres, ourPoints) {
                            case Err(problem) => Err(problem)
                            case Ok(whereLines) =>
                                match atPits(pits, parallel, pitPoints, pitMetres, length) {
                                    case Err(problem) => Err(problem)
                                    case Ok(wherePits) =>
                                        match whereLines {
                                            case (claim, lines) => keep(
                                                {
                                                    circuit = circuit,
                                                    source = source,
                                                    coords = coords,
                                                    corners = corners,
                                                    pits = pits,
                                                    theirMetres = theirMetres,
                                                    origin = origin,
                                                    deviation = deviation,
                                                    atCorners = whereCorners,
                                                    atPits = wherePits,
                                                    pitLength = Option.getWithDefault(0.0, List.last(pitMetres)),
                                                    atLines = lines,
                                                    sectors = claim
                                                }
                                            )
                                        }
                                }
                        }
                }
        }
    }

    /// Each corner where it lands: the atlas's fraction of its own lap against the
    /// metre of this app's line that stands nearest the marker's place.
    def atCorners(
        corners: List[Track.Feature],
        parallel: Float64,
        ourPoints: List[Apart.Point],
        ours: List[Float64],
        length: Float64
    ): Result[String, List[AtCorner]] =
        walkingCorners(corners, parallel, ourPoints, ours, length)

    def walkingCorners(
        rest: List[Track.Feature],
        parallel: Float64,
        ourPoints: List[Apart.Point],
        ours: List[Float64],
        length: Float64
    ): Result[String, List[AtCorner]] =
        match rest {
            case Nil => Ok(Nil)
            case corner :: more =>
                match (Track.placeOf(corner), Track.markerOf(corner)) {
                    case (Err(problem), _) => Err(problem)
                    case (_, Err(problem)) => Err(problem)
                    case (Ok(place), Ok(marker)) =>
                        match walkingCorners(more, parallel, ourPoints, ours, length) {
                            case Err(problem) => Err(problem)
                            case Ok(rows) =>
                                let near = Apart.nearestOn(Apart.projectOn(parallel, place), ourPoints, ours);
                                let spelled = Option.getWithDefault("undefined", Geometry.word("id", Geometry.propertiesOf(corner)));
                                Ok({id = spelled, theirMetres = marker * length, ourMetres = near#metres, distance = near#distance} :: rows)
                        }
                }
        }

    /// Where each line the kept geometry publishes stands on each line: this app's
    /// metre first, and the atlas's answer to that place. The claim itself travels to
    /// the report, which quotes the map it names rather than re-asking the file.
    def atPublished(
        circuit: Circuit,
        ours: Kept,
        theirPoints: List[Apart.Point],
        theirMetres: List[Float64],
        ourPoints: List[Apart.Point]
    ): Result[String, (Option[Track.Sectors], List[AtLine])] =
        match Track.sectorsClaimed(ours#props) {
            case None => Ok((None, Nil))
            case Some(sectors) =>
                match Track.sectorLines(sectors, circuit#lap) {
                    case Err(problem) => Err(problem)
                    case Ok(lines) =>
                        Ok(
                            (
                                Some(sectors),
                                List.map(
                                    line -> {
                                        let near = Apart.nearestOn(Apart.interpolate(ourPoints, ours#metres, line#metres), theirPoints, theirMetres);
                                        {id = line#id, metres = line#metres, theirMetres = near#metres, distance = near#distance}
                                    },
                                    lines
                                )
                            )
                        )
                }
        }

    /// Each pit marker against the pit lane the survey chained: how far it stands from
    /// that lane, and how far along it.
    def atPits(
        pits: List[Track.Feature],
        parallel: Float64,
        pitPoints: List[Apart.Point],
        pitMetres: List[Float64],
        length: Float64
    ): Result[String, List[AtPit]] =
        walkingPits(pits, parallel, pitPoints, pitMetres, length)

    def walkingPits(
        rest: List[Track.Feature],
        parallel: Float64,
        pitPoints: List[Apart.Point],
        pitMetres: List[Float64],
        length: Float64
    ): Result[String, List[AtPit]] =
        match rest {
            case Nil => Ok(Nil)
            case pit :: more =>
                match (Track.placeOf(pit), Track.markerOf(pit)) {
                    case (Err(problem), _) => Err(problem)
                    case (_, Err(problem)) => Err(problem)
                    case (Ok(place), Ok(marker)) =>
                        match walkingPits(more, parallel, pitPoints, pitMetres, length) {
                            case Err(problem) => Err(problem)
                            case Ok(rows) =>
                                let near = Apart.nearestOn(Apart.projectOn(parallel, place), pitPoints, pitMetres);
                                Ok({role = Track.named(pit), theirMetres = marker * length, along = near#metres, distance = near#distance} :: rows)
                        }
                }
        }

    /// The keeping — the only side effect of a run, made once every guard has answered.
    def keep(reading: Reading): Result[String, Reading] \ IO =
        let text = Track.fileText(reading#source, reading#circuit#word, reading#coords, reading#corners, reading#pits, reading#theirMetres);
        match Cli.Errors.writeFile(Circuit.keptAtlas(reading#circuit), text) {
            case Err(problem) => Err("${problem}")
            case Ok(_)        => Ok(reading)
        }

    // -------------------------------------------------------------------- the report

    /// What the reading prints: the apartness of the two lines, and where each atlas
    /// marker — a corner, a pit, a published line — stands on this app's line.
    def report(reading: Reading): Unit \ Console = {
        let circuit = reading#circuit;
        let length = Option.getWithDefault(0.0, List.last(reading#theirMetres));
        let distances = List.map(corner -> corner#distance, reading#atCorners);
        let laps = List.map(corner -> corner#ourMetres - corner#theirMetres, reading#atCorners);
        let worstLap = List.foldLeft((held, each) -> if (Float64.abs(each) > Float64.abs(held)) each else held, 0.0, laps);
        Console.println("== ${circuit#word}: the atlas line against the geometry this app draws");
        Console.println(
            "length: measured ${Util.Format.fixed(1, length)} m against the published ${Util.Format.spelled(circuit#lap)} m "
                + "(${Track.signed(length - circuit#lap)}); "
                + originSentence(circuit, reading#origin)
        );
        Console.println(
            "lines sampled every ${Util.Format.spelled(Apart.defaultEvery())} m (${reading#deviation#count}): mean apart ${Util.Format.fixed(1, reading#deviation#mean)} m, "
                + "max ${Util.Format.fixed(1, reading#deviation#worst#distance)} m at their ${Util.Format.fixed(0, reading#deviation#worst#aMetres)} m, our ${Util.Format.fixed(1, reading#deviation#worst#bMetres)} m"
        );
        Console.println(cornersSentence(distances, laps, worstLap));
        foreach (corner <- reading#atCorners)
            Console.println(
                "  ${corner#id}: marker at ${Util.Format.fixed(1, corner#theirMetres)} m, our line has that place at "
                    + "${Util.Format.fixed(1, corner#ourMetres)} m (${Track.signed(corner#ourMetres - corner#theirMetres)}), ${Util.Format.fixed(1, corner#distance)} m apart"
            );
        if (not List.isEmpty(reading#atPits)) {
            Console.println("pit markers (${List.length(reading#atPits)}), against our own pit lane of ${Util.Format.fixed(1, reading#pitLength)} m:");
            foreach (pit <- reading#atPits)
                Console.println(
                    "  ${pit#role}: the atlas stands it at lap ${Util.Format.fixed(1, pit#theirMetres)} m; "
                        + "${Util.Format.fixed(1, pit#distance)} m from our pit lane, ${Util.Format.fixed(1, pit#along)} m along it"
                )
        } else
            ();
        reportLines(reading)
    }

    def originSentence(circuit: Circuit, origin: Float64): String =
        match circuit#timingLine {
            case Some(_) => "the lap starts ${Util.Format.fixed(1, origin)} m from the published timing line"
            case None    => "the circuit's config names no timing line, so the atlas lap's start goes unchecked"
        }

    def cornersSentence(distances: List[Float64], laps: List[Float64], worstLap: Float64): String =
        if (List.isEmpty(distances))
            "corners (0): the atlas layer holds no corner markers, so nothing was laid against our line"
        else
            "corners (${List.length(distances)}): mean apart ${Util.Format.fixed(1, mean(distances))} m, max ${Util.Format.fixed(1, Option.getWithDefault(0.0, List.maximum(distances)))} m; "
                + "lap distance differs by ${Util.Format.fixed(1, mean(List.map(Float64.abs, laps)))} m on average, worst ${Track.signed(worstLap)} m"

    /// The published lines' own paragraph, which a geometry that publishes no map
    /// simply does not have — and that a map publishing no intermediate line has no
    /// more of, since the last stretch ends where the lap began and is no line to place.
    def reportLines(reading: Reading): Unit \ Console =
        match reading#sectors {
            case Some(sectors) if not List.isEmpty(reading#atLines) =>
                Console.println("the lines ${sectors#source} publishes, on each line:");
                foreach (line <- reading#atLines)
                    Console.println(
                        "  ${line#id} begins at our ${Util.Format.fixed(1, line#metres)} m; the atlas line has that place at "
                            + "${Util.Format.fixed(1, line#theirMetres)} m (${Track.signed(line#theirMetres - line#metres)}), ${Util.Format.fixed(1, line#distance)} m apart"
                    )
            case _ => ()
        }

    def mean(distances: List[Float64]): Float64 =
        List.foldLeft((total, each) -> total + each, 0.0, distances) / Int32.toFloat64(List.length(distances))
}
