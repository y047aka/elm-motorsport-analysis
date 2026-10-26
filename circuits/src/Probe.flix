/// Which relation OpenStreetMap holds a circuit as -- the question asked before a
/// circuit has a config, and the one a config is then authored from.
///
///     nix run .#geometry -- probe 47.96,0.23 --radius 5
///     nix run .#geometry -- probe 47.9661,0.2086,47.9925,0.2405
///
/// Each candidate relation the box holds is printed whole: its tags as they stand,
/// its member ways measured, its roles counted. Around Le Mans the full 13.6 km
/// circuit and the 4.4 km Grand Prix circuit both stand, and the measured lap is
/// what tells them apart -- which is why the report goes to a human and asks
/// nothing of a name.
///
/// Nothing here is written: the answer the report prints is what a circuit's
/// config is authored from, and the pipeline that draws the geometry begins
/// there. `Candidates` is the reading of an answer already got; this is the
/// asking, the two questions and the printing.
pub mod Probe {

    use Candidates.{bboxOf, describe, looksLikeACircuit, measure}
    use Candidates.Box
    use Cli.Args.ArgsError
    use Net.Https.Https
    use Overpass.Element
    use Sys.Console
    use Time.Clock
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    /// How far round each centre to look, and the places to look round.
    pub type alias Request = {
        radius = Float64,
        places = List[String]
    }

    /// How far a centre is widened by default: 5 km, which holds the Grand Prix
    /// circuit at Le Mans and not the full Sarthe one.
    pub def defaultRadius(): Float64 = 5.0

    /// How many candidates get their ways asked for. A box that catches a road
    /// tagged as a route catches it for its whole length.
    pub def probeLimit(): Int32 = 10

    enum Setting with Eq {
        case Help
        case Radius(String)
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
        Cli.Args.helpDescr(Setting.Help) ::
        {
            optionIds     = Nil,
            optionNames   = "radius" :: Nil,
            argDescriptor = ArgDescr.ReqArg(km -> Some(Setting.Radius(km)), "KM"),
            explanation   = "how far round each named centre to look\n(default ${defaultRadius()} km)"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    pub def parse(args: List[String]): Result[ArgsError, Request] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  => requestOf(scanned#options, scanned#words)
        }

    def requestOf(settings: List[Setting], places: List[String]): Result[ArgsError, Request] =
        match radiusOf(settings) {
            case Err(problem) => Err(problem)
            case Ok(radius)   =>
                match places {
                    case Nil   => Err(ArgsError.ParseErrors(placesWanted() :: Nil))
                    case named => Ok({ radius = radius, places = named })
                }
        }

    def placesWanted(): String =
        "the probe reads one or more places, each a <lat>,<lon> centre or a <south>,<west>,<north>,<east> box."

    /// The last `--radius` wins, as a repeated option usually does. Nought and a
    /// negative are refused rather than widened into a box that does not open.
    def radiusOf(settings: List[Setting]): Result[ArgsError, Float64] =
        match Cli.Args.lastNamed(radiusNamed, settings) {
            case None => Ok(defaultRadius())
            case Some(spelled) =>
                match Float64.fromString(spelled) {
                    case Some(km) =>
                        if (km > 0.0)
                            Ok(km)
                        else
                            Err(ArgsError.ParseErrors(notARadius(spelled) :: Nil))
                    case None => Err(ArgsError.ParseErrors(notARadius(spelled) :: Nil))
                }
        }

    def notARadius(spelled: String): String =
        "\"${spelled}\" is not a radius: --radius is kilometres, and more than nought."

    def radiusNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.Radius(km) => Some(km)
            case _                  => None
        }

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "Usage: nix run .#geometry -- probe <lat>,<lon> [...] [--radius <km>], or <south>,<west>,<north>,<east> [...]",
            optionDescrs()
        )

    // ------------------------------------------------------------------- the run

    /// The exit code the probe comes to: 1 for arguments it cannot ask with, and
    /// for a question no runner answered.
    pub def exitCode(args: List[String]): Int32 \ { Clock, Console, IO } =
        Cli.Args.answer(
            optionDescrs(),
            usage(),
            isHelp,
            args,
            scanned -> requestOf(scanned#options, scanned#words),
            request -> Overpass.paced(() -> probeAll(request))
        )

    /// Every place named, probed in turn. The first question no runner answers ends
    /// the run: the next place would be refused for the same reason.
    def probeAll(request: Request): Int32 \ { Console, IO, Https } =
        match Result.traverse(probePlace(request#radius), request#places) {
            case Ok(_) => 0
            case Err(problem) =>
                Console.eprintln("Error: ${problem}");
                1
        }

    /// One place: the box it opens to, the relations the box holds, and each of
    /// those described and -- if its tags could name a circuit -- measured.
    def probePlace(radius: Float64, place: String): Result[String, Unit] \ { Console, IO, Https } =
        match forM(
            box   <- bboxOf(place, radius);
            found <- Overpass.askElements(candidatesOf(box))
        ) yield (box, found) {
            case Err(problem) => Err(problem)
            case Ok((box, found)) =>
                Console.println("\n== ${place} (bbox ${bounds(box)})");
                if (List.isEmpty(found))
                    Console.println(untagged())
                else
                    describeEach(found);
                Ok(())
        }

    /// What a box holding nothing tagged as a circuit means, which is either an
    /// answer about the box or one about OpenStreetMap.
    def untagged(): String =
        "  nothing tagged as a circuit, a motor-sport route or a raceway here. Either the box misses the circuit -- widen it -- or OpenStreetMap holds the ground untagged, and this pipeline, which chains a relation's ways, has nothing to start from."

    /// Each candidate relation the answer names, described; the ones whose tags
    /// could name a circuit are asked again for their ways and measured. A candidate
    /// whose ways come back wrong is reported and the reading goes on.
    def describeEach(elements: List[Element]): Unit \ { Console, IO, Https } =
        let _probed = List.foldLeft((count, element) -> describeOne(probeLimit(), count, element), 0, elements);
        ()

    def describeOne(limit: Int32, probed: Int32, element: Element): Int32 \ { Console, IO, Https } =
        Console.println("  relation ${element#id}  ${describe(element#tags)}");
        if (not looksLikeACircuit(element#tags)) {
            Console.println("      not probed: tagged as neither a circuit, a motor-sport route nor a raceway");
            probed
        } else if (probed >= limit) {
            Console.println("      not probed: the limit of probed candidates is used up");
            probed
        } else {
            match measured(element) {
                case Ok(line)    => Console.println("      ${line}")
                case Err(problem) => Console.println("      probing failed: ${problem}")
            };
            probed + 1
        }

    /// The relation's ways, asked for and measured: the asking is here, the reading
    /// of the answer is `Candidates.measure`'s.
    def measured(element: Element): Result[String, String] \ { IO, Https } =
        Result.flatMap(answer -> measure(answer, element#id), Overpass.askElements(waysOf(element#id)))

    /// The first question: every relation the box holds that is tagged as a
    /// circuit, a motor-sport route or a raceway, with its tags and nothing else.
    /// Which of them is the circuit is the next question's answer.
    def candidatesOf(box: Box): String =
        let extent = bounds(box);
        let selectors =
            "relation[\"type\"=\"circuit\"](${extent});" ::
            "relation[\"sport\"~\"^motor\"](${extent});" ::
            "relation[\"motorsport\"](${extent});" ::
            "relation[\"route\"~\"^(raceway|motorsport|racing)$\"](${extent});" ::
            "relation[\"highway\"=\"raceway\"](${extent});" :: Nil;
        "[out:json][timeout:90];(${String.intercalate("", selectors)});out tags;"

    /// The second question: the relation whole and its ways with their geometry,
    /// which is the only answer a role's length can be measured out of. It stops
    /// at the geometry the runner hands inline — nodes are the survey's question,
    /// the one that chains a lap.
    pub def waysOf(relation: Int64): String =
        "[out:json][timeout:90];relation(${relation});out body;way(r);out geom;"

    /// A box as Overpass takes it in a query, and as the report echoes it back so
    /// that a reader can tell what was asked of the ground.
    def bounds(box: Box): String =
        "${box#s},${box#w},${box#n},${box#e}"
}
