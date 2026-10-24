/// Which relation OpenStreetMap holds a circuit as -- the question asked before a
/// circuit has a config, and the one a config is then authored from.
///
///     nix run .#geometry-probe -- 47.96,0.23 --radius 5
///     nix run .#geometry-probe -- 47.9661,0.2086,47.9925,0.2405
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

    /// The arguments as given, when they are not what the probe asks with.
    pub enum ProbeError {
        case ParseErrors(List[String])
    }

    /// Each case already carries the sentence naming what was wrong; the derived
    /// one would wrap it in constructor syntax before it reaches stderr.
    instance ToString[ProbeError] {
        pub def toString(e: ProbeError): String = match e {
            case ProbeError.ParseErrors(messages) => List.join(" ", messages)
        }
    }

    /// How far a centre is widened by default: 5 km, which holds the Grand Prix
    /// circuit at Le Mans and not the full Sarthe one. Widening it is the reader's
    /// call, which is why the box a run opened is printed back.
    pub def defaultRadius(): Float64 = 5.0

    /// How many candidates get their ways asked for. A box that catches a road
    /// tagged as a route catches it for its whole length, and the ways of ten
    /// candidates are more than anyone reads off a report anyway.
    pub def probeLimit(): Int32 = 10

    enum Setting {
        case Radius(String)
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
        {
            optionIds     = Nil,
            optionNames   = "radius" :: Nil,
            argDescriptor = ArgDescr.ReqArg(km -> Some(Setting.Radius(km)), "KM"),
            explanation   = "how far round each named centre to look\n(default ${defaultRadius()} km)"
        } :: Nil

    pub def parse(args: List[String]): Result[ProbeError, Request] =
        match Util.GetOpt.getOpt(Util.GetOpt.ArgOrder.Permute, optionDescrs(), args) {
            case Validation.Failure(errors) => Err(ProbeError.ParseErrors(Nec.toList(errors)))
            case Validation.Success(result) => requestOf(result#options, result#nonOptions)
        }

    def requestOf(settings: List[Setting], places: List[String]): Result[ProbeError, Request] =
        match radiusOf(settings) {
            case Err(problem) => Err(problem)
            case Ok(radius)   =>
                match places {
                    case Nil   => Err(ProbeError.ParseErrors(placesWanted() :: Nil))
                    case named => Ok({ radius = radius, places = named })
                }
        }

    def placesWanted(): String =
        "the probe reads one or more places, each a <lat>,<lon> centre or a <south>,<west>,<north>,<east> box."

    /// The last `--radius` wins, as a repeated option usually does. Nought and a
    /// negative are refused rather than widened into a box that does not open: a
    /// reader who meant a distance and typed one that asks nothing should be told
    /// which of the two happened.
    def radiusOf(settings: List[Setting]): Result[ProbeError, Float64] =
        match last(lastRadius, settings) {
            case None => Ok(defaultRadius())
            case Some(spelled) =>
                match Float64.fromString(spelled) {
                    case Some(km) =>
                        if (km > 0.0)
                            Ok(km)
                        else
                            Err(ProbeError.ParseErrors(notARadius(spelled) :: Nil))
                    case None => Err(ProbeError.ParseErrors(notARadius(spelled) :: Nil))
                }
        }

    def notARadius(spelled: String): String =
        "\"${spelled}\" is not a radius: --radius is kilometres, and more than nought."

    def lastRadius(setting: Setting): Option[String] =
        match setting {
            case Setting.Radius(km) => Some(km)
        }

    /// The last answer to a repeated option, which is the one the reader meant.
    def last(asking: Setting -> Option[String], settings: List[Setting]): Option[String] =
        List.foldLeft(
            (acc, setting) -> {
                let asked = asking(setting);
                match asked {
                    case None    => acc
                    case Some(_) => asked
                }
            },
            None,
            settings
        )

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "Usage: geometry-probe <lat>,<lon> [...] [--radius <km>], or <south>,<west>,<north>,<east> [...]",
            optionDescrs()
        )

    // ------------------------------------------------------------------- the run

    /// The exit code the probe comes to: 1 for arguments it cannot ask with, and
    /// for a question no runner answered.
    pub def exitCode(args: List[String]): Int32 \ { Clock, Console, IO } =
        match parse(args) {
            case Err(problem) =>
                Console.eprintln("Error: ${problem}");
                Console.eprintln(usage());
                1
            case Ok(request) =>
                Overpass.paced(() -> probeAll(request))
        }

    /// Every place named, probed in turn. The first question no runner answers ends
    /// the run: the next place would be refused for the same reason, and going on
    /// would print nothing new in the time it took.
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
            found <- Overpass.ask(candidatesOf(box))
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
    /// could name a circuit are asked again for their ways and measured. A
    /// candidate whose ways come back wrong is reported and the reading of the
    /// answer goes on: one relation that times out is no reason to stop reading
    /// the answer that named it.
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
        Result.flatMap(answer -> measure(answer, element#id), Overpass.ask(waysOf(element)))

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
    /// which is the only answer a role's length can be measured out of.
    def waysOf(element: Element): String =
        "[out:json][timeout:90];relation(${element#id});out body;way(r);out geom;"

    /// A box as Overpass takes it in a query, and as the report echoes it back so
    /// that a reader can tell what was asked of the ground.
    def bounds(box: Box): String =
        "${box#s},${box#w},${box#n},${box#e}"
}
