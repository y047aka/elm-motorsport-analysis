/// Reads one circuit's measured line out of the track-atlas dataset — its outline's
/// edges are measured off orthoimagery registered to lidar, with OpenStreetMap's
/// centreline fixing the lap order, origin and direction — and keeps it in this
/// repository's geometry profile, at the atlas length and *not* stretched.
///
///     nix run .#geometry -- atlas cota [--file gp.geojson] [--fetch]
///
/// The reading is offline by default, as the survey is: `--fetch` is the one flag
/// that asks the layer's home. A circuit with no kept line answers the sentence
/// saying so and exits 0. A circuit joins the reading by carrying an `atlas` entry
/// naming the layer for the layout this app draws; a circuit without one is asked
/// nothing. It prints four readings: how far the lines stand apart in metres;
/// whether the atlas corner markers land at the lap distances this app's geometry
/// puts them at; whether the atlas pit entry and exit stand on that geometry's pit
/// lane; and where the circuit's published sector lines stand on each line.
///
/// The apartness math is `Apart`'s, shared with the diff; the feature shape checks,
/// the guards and the written file are `Midline`'s. This file adds only the measuring.
/// and the plane they are all measured on is `Geodesy`'s, which is also where the
/// atlas line's own metres come from — no reading of this one reaches into `Survey`.
///
/// The atlas data is © its contributors under the ODbL, itself derived from OpenStreetMap
/// and open orthoimagery; the written file carries the source URL beside the license.
pub mod Atlas {

    use Circuit.Circuit
    use Circuit.Publishes
    use Cli.Args.ArgsError
    use Cli.Args.Outcome
    use Geodesy.Place
    use Geodesy.cumulative
    use Geodesy.parallelOf
    use Geodesy.projectOn
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
        theirLine   = List[Geodesy.Metred],
        corners     = List[Geometry.Feature],
        pits        = List[Geometry.Feature],
        origin      = Float64,
        deviation   = Apart.Apartness,
        atCorners   = List[AtCorner],
        atPits      = List[AtPit],
        pitLength   = Float64,
        atLines     = List[AtLine],
        sectors     = Option[Publishes]
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
    /// `Midline.sectorsClaimed`, which is where a half-claim reads as no claim.
    type alias Kept = {
        line   = List[Geodesy.Metred],
        pit    = List[Place],
        props  = Map[String, Json]
    }

    /// The layer's three kinds of feature, read out of one file: the line the atlas
    /// measured, its corner markers, and whichever pit markers it holds.
    type alias Layer = {
        outline = Geometry.Feature,
        corners = List[Geometry.Feature],
        pits    = List[Geometry.Feature]
    }

    // ------------------------------------------------------------------- the command

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "usage: nix run .#geometry -- atlas <circuit> [--fetch] [--file <atlas.geojson>]",
            optionDescrs()
        )

    /// What a run asks: the circuit, the layer named if one was, and whether the
    /// layer's home is asked now.
    pub type alias Request = {
        circuit = Circuit,
        file    = Option[String],
        fetch   = Bool
    }

    enum Setting with Eq {
        case Fetch
        case File(String)
        case Help
    }

    /// `--fetch` and `--file <path>`, and nothing else a run does not know. One run
    /// reads one layer.
    def optionDescrs(): List[OptionDescr[Setting]] =
        Cli.Args.helpDescr(Setting.Help) ::
        {
            optionIds     = Nil,
            optionNames   = "fetch" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.Fetch),
            explanation   = "ask the circuit's atlas layer now and keep its line\nhere instead of reading the kept one"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "file" :: Nil,
            argDescriptor = ArgDescr.ReqArg(path -> Some(Setting.File(path)), "ATLAS.GEOJSON"),
            explanation   = "read this kept layer instead of the circuit's own"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    def isFetched(setting: Setting): Bool =
        setting == Setting.Fetch

    /// The exit code the reading comes to: 1 for a word no circuit answers to, a
    /// circuit with no atlas layer, a file that would not read or a line that failed a
    /// guard, and 0 once the line is measured and kept — or when a run handed no
    /// `--fetch` has no kept line to measure yet.
    pub def exitCode(args: List[String]): Int32 \ { IO, Console } =
        Cli.Args.comeTo(arguments(args), asking)

    /// The arguments as far as the flag table reads them, before the reading asks
    /// which circuit and which layer were named.
    pub def arguments(args: List[String]): Cli.Args.Parsed[Request] =
        Cli.Args.prepare(optionDescrs(), usage(), isHelp, completed, args)

    /// The measuring, with the layer's home handled here and nowhere else: a run that
    /// only asked for help, or asked with a wrong argument, asks a dataset's
    /// repository for nothing.
    def asking(asked: Request): Outcome \ { IO, Console } =
        Net.Https.runWithIO(() -> measured(asked))

    /// What the reading comes to: a circuit that keeps no line and raised no
    /// `--fetch` says so and exits 0; a line that was read is measured, kept
    /// and printed.
    def measured(asked: Request): Outcome \ { IO, Console, Https } =
        match text(asked) {
            case Err(problem)      => Outcome.Failed(problem)
            case Ok(None)          => Outcome.Done(noLine(asked#circuit) :: Nil)
            case Ok(Some(spelled)) => Cli.Args.outcomeOf(measure(asked, spelled))
        }

    def noLine(circuit: Circuit): String =
        "${circuit#word}: no kept atlas line yet — `--fetch` asks the layer's home and keeps one"

    /// The circuit to read, and where its layer comes from.
    pub def parse(args: List[String]): Result[ArgsError, Request] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  => completed(scanned)
        }

    def completed(scanned: Cli.Args.Scanned[Setting]): Result[ArgsError, Request] =
        complete(
            scanned#words,
            Cli.Args.lastNamed(fileNamed, scanned#options),
            List.exists(isFetched, scanned#options)
        )

    /// A flag is no file, as at the other commands; and `--file` beside `--fetch`
    /// is opposite answers for one layer.
    def complete(words: List[String], file: Option[String], fetch: Bool): Result[ArgsError, Request] =
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
                                    else if (Option.nonEmpty(file) and fetch)
                                        Err(ArgsError.ParseErrors("--file and --fetch ask for opposite things: a layer already kept, and one asked now." :: Nil))
                                    else
                                        Ok({circuit = circuit, file = file, fetch = fetch})
                            }
                    }
        }

    def fileNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.File(path) => Some(path)
            case _                  => None
        }

    // ------------------------------------------------------------------ the measuring

    /// The layer read — asked now, read from the named file, or read from the line
    /// the circuit keeps — measured against the geometry the app serves, and kept
    /// beside the config. The guards all answer before anything is written: a line
    /// that is another circuit's, or starts at another line, never reaches disk.
    def measure(asked: Request, spelled: String): Result[String, Outcome] \ { IO, Console } =
        forM(
            layer   <- layerOf(spelled, asked#circuit#word);
            markers <- placesOf(layer#corners ++ layer#pits);
            ours    <- keptGeometry(asked#circuit);
            reading <- measuredAgainst(asked, layer, markers, ours)
        ) yield printed(reading)

    /// The readings printed. The file was kept by the measuring, so a run that got
    /// this far has something to show and goes well.
    def printed(reading: Reading): Outcome \ Console = {
        report(reading);
        Outcome.Done(Nil)
    }

    /// The circuit's own line read out of the layer, and measured on the plane the
    /// kept geometry is already drawn on.
    def measuredAgainst(asked: Request, layer: Layer, markers: List[Place], ours: Kept): Result[String, Reading] \ IO =
        Midline.lineOf(layer#outline)
            |> Result.flatMap(coords -> laid(asked#circuit, sourceOf(asked), coords, layer#corners, layer#pits, markers, ours))

    /// The source the kept file claims, which is the circuit's atlas URL whether the
    /// line came from its home or from a kept file: a reading from a kept file re-keeps
    /// the line that URL's survey measured, and a file path would credit the line to
    /// whomever saved it last.
    def sourceOf(asked: Request): String =
        Option.getWithDefault("", asked#circuit#atlas)

    /// The layer's text: from its home on `--fetch`, from the named file, or from the
    /// line the circuit keeps.
    def text(asked: Request): Result[String, Option[String]] \ { IO, Https } =
        match asked#circuit#atlas {
            case None => Err("${asked#circuit#word}'s config names no atlas layer to read")
            case Some(url) =>
                if (asked#fetch)
                    ask(url) |> Result.map(spelled -> Some(spelled))
                else
                    match asked#file {
                        case Some(path) =>
                            Cli.Errors.readFile(path) |>
                                Result.mapErr(problem -> "${problem}") |>
                                Result.map(spelled -> Some(spelled))
                        case None => keptLine(asked#circuit)
                    }
        }

    /// Whether the circuit keeps a line at all, which is the reading's one `None`:
    /// nothing kept where the circuit's own line should stand is a verdict, while a line
    /// that is there and will not read is a failure — a read's own failure says only that
    /// nothing came.
    def keptLine(circuit: Circuit): Result[String, Option[String]] \ IO =
        let at = Circuit.keptAtlas(circuit);
        match Util.Files.exists(at) {
            case Err(problem) => Err(problem)
            case Ok(false)    => Ok(None)
            case Ok(true) =>
                Cli.Errors.readFile(at) |>
                    Result.mapErr(problem -> "${problem}") |>
                    Result.map(spelled -> Some(spelled))
        }

    /// The layer asked of its home: once, without retries — a dataset's repository is
    /// not a busy map, and a run that missed it can be run again. What counts as an
    /// answer is the reading the survey's runners are read by, under this URL's own name.
    def ask(url: String): Result[String, String] \ Https =
        match Https.send(getting(url)) {
            case Err(error)   => Err(Overpass.worded(error))
            case Ok(response) => Overpass.answered(response, url)
        }

    def getting(url: String): HttpRequest =
        url |> HttpRequest.get |> HttpRequest.withHeader("User-Agent", userAgent())

    /// The layer read down to its three kinds of feature: the outline that is the line,
    /// the corners, and whichever pit markers the layer holds. The identity guard is
    /// asked here, at the first reading of the file: a file measured from another
    /// circuit replaces one circuit's kept evidence with another's, and does it quietly.
    def layerOf(spelled: String, word: String): Result[String, Layer] =
        match Util.Json.parse(spelled) |> Result.mapErr(problem -> "the atlas file does not parse: ${problem}") {
            case Err(problem) => Err(problem)
            case Ok(json) =>
                let features = Geometry.featuresOf(json);
                forM(
                    outline <- outlineOf(features);
                    _       <- Midline.checkIdentity(Geometry.word("circuit", Geometry.propertiesOf(outline)), word)
                ) yield {outline = outline, corners = cornersOf(features), pits = pitsOf(features)}
        }

    def outlineOf(features: List[Geometry.Feature]): Result[String, Geometry.Feature] =
        match List.find(feature -> Midline.roleOf(feature) == Some("outline"), features) {
            case Some(one) => Ok(one)
            case None      => Err("the atlas file holds no outline feature")
        }

    def cornersOf(features: List[Geometry.Feature]): List[Geometry.Feature] =
        List.filter(feature -> Midline.roleOf(feature) == Some("corner"), features)

    /// The pit markers, one per role, entry before exit: what a layer holds under a
    /// role twice is one entry and one exit to this reading, in the order a pit lane
    /// is driven rather than the order a file happens to hold.
    def pitsOf(features: List[Geometry.Feature]): List[Geometry.Feature] =
        List.filterMap(
            role -> List.find(feature -> Midline.roleOf(feature) == Some(role), features),
            "pit_entry" :: "pit_exit" :: Nil
        )

    /// The markers' places, asked before any measuring: a marker that carries no point
    /// fails the run rather than joining the mean as a nought.
    def placesOf(markers: List[Geometry.Feature]): Result[String, List[Place]] =
        List.foldRight(
            (feature, places) -> match (Midline.placeOf(feature), places) {
                case (Ok(one), Ok(many)) => Ok(one :: many)
                case (Err(problem), _)   => Err(problem)
                case (_, Err(problem))   => Err(problem)
            },
            Ok(Nil),
            markers
        )

    /// The kept geometry read beside the config.
    def keptGeometry(circuit: Circuit): Result[String, Kept] \ IO =
        match Cli.Errors.readFile(circuit#file) {
            case Err(problem) => Err("${problem}")
            case Ok(text) =>
                match (Geometry.outline(circuit#word, text), Geometry.pitLane(circuit#word, text)) {
                    case (Ok(outline), Ok(pit)) =>
                        Ok({line = Geodesy.together(outline#coords, outline#metres), pit = pit, props = claimed(text)})
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

    /// Both lines on one plane, and every reading taken on it. The projection is laid
    /// over the two lines and all the markers together, so neither line is drawn at a
    /// scale of its own.
    def laid(
        circuit: Circuit,
        source: String,
        coords: List[Place],
        corners: List[Geometry.Feature],
        pits: List[Geometry.Feature],
        markers: List[Place],
        ours: Kept
    ): Result[String, Reading] \ IO = {
        let ourPlaces = List.map(each -> each#place, ours#line);
        let ourMetres = List.map(each -> each#metre, ours#line);
        match Geodesy.parallelOf(coords ++ ourPlaces ++ ours#pit ++ markers) {
            case None => Err("neither line holds a place, so there is no plane to lay them on")
            case Some(parallel) => {
                let onto = place -> Geodesy.projectOn(parallel, place);
                let theirPoints = List.map(onto, coords);
                let ourPoints = List.map(onto, ourPlaces);
                let theirMetres = Geodesy.cumulative(theirPoints);
                let pitPoints = List.map(onto, ours#pit);
                let pitMetres = Geodesy.cumulative(pitPoints);
                let length = theirMetres |> List.last |> Option.getWithDefault(0.0);
                let first = coords |> List.head |> Option.getWithDefault({lon = 0.0, lat = 0.0});
                match forM(
                    theirLine      <- Apart.line(theirPoints, theirMetres);
                    ourLine        <- Apart.line(ourPoints, ourMetres);
                    pitLine        <- Apart.line(pitPoints, pitMetres);
                    origin         <- Midline.checkOrigin(first, circuit#timingLine);
                    deviation      <- Apart.apartness(theirLine, ourLine, Apart.defaultEvery());
                    whereCorners   <- atCorners(corners, parallel, ourLine, length);
                    published      <- atPublished(circuit, ours, theirLine, ourLine);
                    wherePits      <- atPits(pits, parallel, pitLine, length)
                ) yield {
                    circuit = circuit,
                    source = source,
                    theirLine = Geodesy.together(coords, theirMetres),
                    corners = corners,
                    pits = pits,
                    origin = origin,
                    deviation = deviation,
                    atCorners = whereCorners,
                    atPits = wherePits,
                    pitLength = pitMetres |> List.last |> Option.getWithDefault(0.0),
                    atLines = published#atLines,
                    sectors = published#sectors
                } {
                    case Ok(reading) => keep(reading)
                    case Err(problem) => Err(problem)
                }
            }
        }
    }

    /// Each corner where it lands: the atlas's fraction of its own lap against the
    /// metre of this app's line that stands nearest the marker's place.
    def atCorners(
        corners: List[Geometry.Feature],
        parallel: Float64,
        ourLine: List[Apart.Metred],
        length: Float64
    ): Result[String, List[AtCorner]] =
        corners |> Result.traverse(atCorner(parallel, ourLine, length))

    def atCorner(
        parallel: Float64,
        ourLine: List[Apart.Metred],
        length: Float64,
        corner: Geometry.Feature
    ): Result[String, AtCorner] =
        match (Midline.placeOf(corner), Midline.markerOf(corner)) {
            case (Err(problem), _) => Err(problem)
            case (_, Err(problem)) => Err(problem)
            case (Ok(place), Ok(marker)) =>
                let spelled = corner |> Geometry.propertiesOf |> Geometry.word("id") |> Option.getWithDefault("undefined");
                match place |> Geodesy.projectOn(parallel) |> Apart.nearestOn(ourLine) {
                    case None => Err("the line this app draws holds no places, so corner ${spelled} stands nowhere on it")
                    case Some(near) =>
                        Ok({id = spelled, theirMetres = marker * length, ourMetres = near#metres, distance = near#distance})
                }
        }

    /// Where each line the kept geometry publishes stands on each line: this app's
    /// metre first, and the atlas's answer to that place. The claim itself travels to
    /// the report, which quotes the map it names rather than re-asking the file.
    type alias Published = {
        sectors = Option[Publishes],
        atLines = List[AtLine]
    }

    def atPublished(
        circuit: Circuit,
        ours: Kept,
        theirLine: List[Apart.Metred],
        ourLine: List[Apart.Metred]
    ): Result[String, Published] =
        match Midline.sectorsClaimed(ours#props) {
            case None => Ok({sectors = None, atLines = Nil})
            case Some(sectors) =>
                match Midline.sectorLines(sectors, circuit#lap) {
                    case Err(problem) => Err(problem)
                    case Ok(lines) =>
                        Result.traverse(
                            line ->
                                match line#metres |> Apart.interpolate(ourLine) |> Apart.nearestOn(theirLine) {
                                    case None => Err("the atlas line holds no places, so ${line#id} stands nowhere on it")
                                    case Some(near) =>
                                        Ok({id = line#id, metres = line#metres, theirMetres = near#metres, distance = near#distance})
                                },
                            lines
                        )
                        |> Result.map(atLines -> {sectors = Some(sectors), atLines = atLines})
                }
        }

    /// Each pit marker against the pit lane the survey chained: how far it stands from
    /// that lane, and how far along it.
    def atPits(
        pits: List[Geometry.Feature],
        parallel: Float64,
        pitLine: List[Apart.Metred],
        length: Float64
    ): Result[String, List[AtPit]] =
        pits |> Result.traverse(atPit(parallel, pitLine, length))

    def atPit(
        parallel: Float64,
        pitLine: List[Apart.Metred],
        length: Float64,
        pit: Geometry.Feature
    ): Result[String, AtPit] =
        match (Midline.placeOf(pit), Midline.markerOf(pit)) {
            case (Err(problem), _) => Err(problem)
            case (_, Err(problem)) => Err(problem)
            case (Ok(place), Ok(marker)) =>
                match place |> Geodesy.projectOn(parallel) |> Apart.nearestOn(pitLine) {
                    case None => Err("this app's pit lane holds no places, so ${Midline.named(pit)} stands nowhere on it")
                    case Some(near) =>
                        Ok({role = Midline.named(pit), theirMetres = marker * length, along = near#metres, distance = near#distance})
                }
        }

    /// The keeping — the only side effect of a run, made once every guard has answered.
    def keep(reading: Reading): Result[String, Reading] \ IO =
        let text = Midline.file(reading#source, reading#circuit#word, reading#theirLine, reading#corners, reading#pits);
        forM(
            _ <- Cli.Errors.writeFile(Circuit.keptAtlas(reading#circuit), text) |> Result.mapErr(problem -> "${problem}")
        ) yield reading

    // -------------------------------------------------------------------- the report

    /// What the reading prints: the apartness of the two lines, and where each atlas
    /// marker — a corner, a pit, a published line — stands on this app's line.
    def report(reading: Reading): Unit \ Console = {
        let circuit = reading#circuit;
        let length = reading#theirLine |> List.last |> Option.map(each -> each#metre) |> Option.getWithDefault(0.0);
        let distances = List.map(corner -> corner#distance, reading#atCorners);
        let laps = List.map(corner -> corner#ourMetres - corner#theirMetres, reading#atCorners);
        let worstLap = List.foldLeft((held, each) -> if (Float64.abs(each) > Float64.abs(held)) each else held, 0.0, laps);
        Console.println("== ${circuit#word}: the atlas line against the geometry this app draws");
        Console.println(
            "length: measured ${Util.Format.fixed(1, length)} m against the published ${Util.Format.spelled(circuit#lap)} m "
                + "(${Midline.signed(length - circuit#lap)}); "
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
                    + "${Util.Format.fixed(1, corner#ourMetres)} m (${Midline.signed(corner#ourMetres - corner#theirMetres)}), ${Util.Format.fixed(1, corner#distance)} m apart"
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
                + "lap distance differs by ${laps |> List.map(Float64.abs) |> mean |> Util.Format.fixed(1)} m on average, worst ${Midline.signed(worstLap)} m"

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
                            + "${Util.Format.fixed(1, line#theirMetres)} m (${Midline.signed(line#theirMetres - line#metres)}), ${Util.Format.fixed(1, line#distance)} m apart"
                    )
            case _ => ()
        }

    def mean(distances: List[Float64]): Float64 =
        List.foldLeft((total, each) -> total + each, 0.0, distances) / Int32.toFloat64(List.length(distances))
}
