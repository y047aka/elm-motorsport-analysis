/// The survey read, the lap chained, and the line stretched to the length the circuit
/// publishes: what stands between an Overpass answer and the geometry the app serves.
///
/// A relation lists its ways in no order, may draw a two-way way against the direction of
/// the race, and comes to whatever length OpenStreetMap happens to hold; what the drawing
/// asks for is one closed line that starts at the line the circuit times from, runs in the
/// direction the race does, and ends at the metre the circuit publishes. Every point keeps
/// the degrees it was surveyed at — the metres are this module's working, and the app
/// re-derives them from the frame written beside them.
///
/// An answer's text is `Overpass.Answer`'s to read and its question is `Overpass.Query`'s
/// to spell; the metres are `Geodesy`'s to measure. What is here is the walking of a
/// relation's ways into one line and the laying of that line out in the drawing's units.
///
/// The `survey` word is answered here too, over an answer read from disk or asked of
/// OpenStreetMap now; the bytes it lays or compares are `Geometry.Write`'s, which the
/// regeneration fence and the atlas writer lay too.
pub mod Survey {

    use Circuit.Circuit
    use Cli.Args.ArgsError
    use Cli.Args.Outcome
    use Cli.Errors.CliError
    use Geodesy.Frame
    use Geodesy.Place
    use Geodesy.Point
    use Geodesy.apart
    use Geodesy.cumulative
    use Geodesy.hypot
    use Geodesy.northWest
    use Geodesy.parallelOf
    use Geodesy.polylineMetres
    use Geodesy.projectOn
    use Geodesy.roundTenth
    use Overpass.Answer.Answer
    use Overpass.Answer.Element
    use Overpass.Answer.Member
    use Sys.Console
    use Time.Clock
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    // ---------------------------------------------------------------- the geometry

    /// The lap, the pit lane and the frame, in the drawing's own metres.
    pub type alias Geometry = {
        centreline     = List[Geodesy.Metred],
        pitLane        = List[Place],
        frame          = Frame,
        direction      = String,
        surveyedAt     = Option[String],
        surveyedLength = Option[Float64]
    }

    /// Which way a car goes round the drawing, as the geometry says it goes.
    pub def clockwise(): String = "clockwise"

    pub def counterClockwise(): String = "counter_clockwise"

    /// Metres a thinned line may stray from the surveyed one.
    pub def tolerance(): Float64 = 1.0

    /// An answer read and surveyed: the text a run was handed, the answer it reads as and
    /// the geometry the file is written from. The live survey, the guard a fetched answer
    /// passes before it is kept, and the regeneration fence all travel through here, so an
    /// answer that fails for one of them fails for the other two for the same reason, in
    /// the same words.
    pub type alias Read = {
        text     = String,
        answer   = Answer,
        geometry = Survey.Geometry
    }

    pub def geometry(text: String, circuit: Circuit): Result[String, Read] =
        forM(
            reading  <- Overpass.Answer.read(text);
            surveyed <- geometryOf(reading, circuit)
        ) yield {text = text, answer = reading, geometry = surveyed}

    /// The lap, the pit lane and the frame, chained out of an answer already read.
    pub def geometryOf(reading: Answer, circuit: Circuit): Result[String, Geometry] =
        let nodes = nodesOf(reading);
        let ways = waysOf(reading);
        forM(
            relation <- relationOf(reading, circuit#relation);
            start    <- lineOf(relation, circuit);
            _        <- standsAtLine(relation#members, nodes, start, circuit);
            lap      <- chained(relation, ways, nodes, start);
            pit      <- pitChained(relation, ways, nodes)
        ) yield laidOut(reading, nodes, lap, pit, circuit)

    def relationOf(reading: Answer, relation: Int64): Result[String, Element] =
        match List.find(each -> each#kind == "relation" and each#id == relation, reading#elements) {
            case Some(one) => Ok(one)
            case None      => Err("the answer holds no relation ${relation}")
        }

    /// Every place the answer holds a node for, by its id. A node the answer does not hold
    /// is dropped rather than guessed at, and shows up as a lap with a place missing.
    def nodesOf(reading: Answer): Map[Int64, Place] =
        paired(
            List.filterMap(
                each -> match each#at {
                    case Some(at) => Some((each#id, at))
                    case None     => None
                },
                List.filter(each -> each#kind == "node", reading#elements)
            )
        )

    def waysOf(reading: Answer): Map[Int64, Element] =
        paired(List.map(each -> (each#id, each), List.filter(each -> each#kind == "way", reading#elements)))

    /// The relation member the lap is measured from. A circuit says which role tags it, and
    /// getting it wrong moves the whole field down the lap by the distance between two tagged
    /// lines while still drawing fine.
    def lineOf(relation: Element, circuit: Circuit): Result[String, Int64] =
        match List.find(member -> member#role == circuit#timedFrom, relation#members) {
            case Some(member) => Ok(member#ref)
            case None         => Err("relation ${circuit#relation} tags no member with role '${circuit#timedFrom}'")
        }

    /// The line the lap is measured from, checked against where the circuit says it stands.
    /// A refusal lists the lines the relation does tag and how far each stands from the
    /// published place, which is the reading the reader needed in the first place.
    def standsAtLine(members: List[Member], nodes: Map[Int64, Place], start: Int64, circuit: Circuit): Result[String, Float64] =
        match circuit#timingLine {
            case None => Ok(0.0)
            case Some(line) =>
                match Map.get(start, nodes) {
                    case None =>
                        Err("role=${circuit#timedFrom} names node ${start}, which the answer holds no place for")
                    case Some(at) =>
                        let distance = apart(at, line#place);
                        let limit = Option.getWithDefault(Circuit.nodeWithin(), line#within);
                        if (distance > limit)
                            Err(
                                "role=${circuit#timedFrom} is ${Util.Format.fixed(1, distance)} m from the published timing line, which is not within ${Util.Format.whole(limit)} m. ${relationLines(members, nodes, line)}"
                            )
                        else
                            Ok(distance)
                }
        }

    def relationLines(members: List[Member], nodes: Map[Int64, Place], line: Circuit.TimingLine): String =
        let distances = List.filterMap(
            member -> Option.map(
                at -> "role=${member#role} is ${Util.Format.fixed(1, apart(at, line#place))} m from it",
                Map.get(member#ref, nodes)
            ),
            List.filter(member -> member#kind == "node", members)
        );
        "The relation's lines: ${String.intercalate("; ", distances)}."

    // ---------------------------------------------------------------- chaining a lap

    /// One way of a relation, as a chain sees it: the node ids its line runs through, and
    /// whether traffic drives it one way — which is the only permission a chain has to turn a
    /// way around.
    pub type alias Segment = {
        id     = Int64,
        nodes  = List[Int64],
        oneway = Bool
    }

    /// The lap: the ways the relation lists with no role, chained from the line the lap is
    /// measured from, turned to start there, and closed back onto it.
    def chained(relation: Element, ways: Map[Int64, Element], nodes: Map[Int64, Place], start: Int64): Result[String, List[Int64]] =
        forM(
            segments <- lapSegments(relation, ways);
            track    <- chain(segments, nodes, Some(start))
        ) yield List.append(rotate(withoutLast(track), start), start :: Nil)

    /// The pit lane, chained from whichever of its ways begins where no other way ends: a pit
    /// lane is drawn and never timed, so it has no line to start at and no expectation of
    /// closing back onto one.
    def pitChained(relation: Element, ways: Map[Int64, Element], nodes: Map[Int64, Place]): Result[String, List[Int64]] =
        pitSegments(relation, ways)
            |> Result.flatMap(segments -> chain(segments, nodes, None))

    /// The ways a lap is chained from are the ones the relation puts on no line at all.
    def lapSegments(relation: Element, ways: Map[Int64, Element]): Result[String, List[Segment]] =
        relation#members
            |> List.filter(member -> member#kind == "way" and member#role == "")
            |> Result.traverse(wayOf(relation, ways))

    /// A pit lane's members are named by their role alone: a relation may tag a node as part
    /// of a pit lane, and that is a member no line can be chained out of.
    def pitSegments(relation: Element, ways: Map[Int64, Element]): Result[String, List[Segment]] =
        relation#members
            |> List.filter(member -> member#role == "pit_lane")
            |> Result.traverse(wayOf(relation, ways))

    def wayOf(relation: Element, ways: Map[Int64, Element], member: Member): Result[String, Segment] =
        match Map.get(member#ref, ways) {
            case Some(way) => Ok({id = way#id, nodes = way#nodes, oneway = Map.get("oneway", way#tags) == Some("yes")})
            case None      => Err("relation ${relation#id} names way ${member#ref}, which the answer does not hold")
        }

    /// The walk. The way a lap opens with is the one carrying the line the race times across,
    /// which must be driven the way the race goes round; after it, a way drawn forwards is
    /// taken forwards and a way that is not driven one way may be taken backwards, which is
    /// what closes a lap out of ways each mapper drew in the direction they happened to walk.
    pub def chain(segments: List[Segment], nodes: Map[Int64, Place], start: Option[Int64]): Result[String, List[Int64]] =
        match openedAt(segments, start) {
            case None => Err("the relation holds no way the lap can start from")
            case Some(first) =>
                let walked = walked(segments, Set.insert(first#id, Set.empty()), first#nodes);
                match leftOver(segments, walked#used, walked#ids, nodes) {
                    case Err(problem) => Err(problem)
                    case Ok(_) =>
                        if (Option.nonEmpty(start) and not closes(nodes, walked#ids))
                            Err("the lap does not close: its last point stands ${unclosed(nodes, walked#ids)} m from its first")
                        else
                            Ok(walked#ids)
                }
        }

    /// The way the chain opens with. Of a lap it is the way carrying the timed line, which
    /// fixes the direction it is taken in; of a line with no such claim — a pit lane — it is
    /// the way no other way runs into, which fixes the end it starts from.
    def openedAt(segments: List[Segment], start: Option[Int64]): Option[Segment] =
        match start {
            case Some(at) => List.find(segment -> List.memberOf(at, segment#nodes) and segment#oneway, segments)
            case None => List.find(candidate -> not runsIntoOther(candidate, segments), segments)
        }

    /// Whether some other way ends where this one begins, which is what makes a way the
    /// beginning of an open line rather than a link in it.
    def runsIntoOther(candidate: Segment, segments: List[Segment]): Bool =
        List.exists(
            other -> other#id != candidate#id and List.last(other#nodes) == List.head(candidate#nodes),
            segments
        )

    /// The walk over the relation's ways, keeping which have been taken: a way is taken once,
    /// and the ids it adds are its own or its reverse, less the place the chain already stood
    /// at.
    def walked(segments: List[Segment], used: Set[Int64], ids: List[Int64]): {ids = List[Int64], used = Set[Int64]} =
        match List.last(ids) {
            case None      => {ids = ids, used = used}
            case Some(end) =>
                match nextOf(segments, used, end) {
                    case None => {ids = ids, used = used}
                    case Some(next) =>
                        let taken = if (List.head(next#nodes) == Some(end)) next#nodes else List.reverse(next#nodes);
                        walked(segments, Set.insert(next#id, used), List.append(ids, List.drop(1, taken)))
                }
        }

    def nextOf(segments: List[Segment], used: Set[Int64], end: Int64): Option[Segment] =
        match List.find(segment -> not taken(segment, used) and List.head(segment#nodes) == Some(end), segments) {
            case Some(one) => Some(one)
            case None => List.find(segment -> not taken(segment, used) and not segment#oneway and List.last(segment#nodes) == Some(end), segments)
        }

    def taken(segment: Segment, used: Set[Int64]): Bool = Set.memberOf(segment#id, used)

    /// The ways the chain could not take, which is a failure and never a shortened lap.
    /// Every way left out is reported with what decides its remedy — its length, how far its
    /// nearest end stands from where the chain stopped, and whether it is driven one way.
    def leftOver(segments: List[Segment], used: Set[Int64], ids: List[Int64], nodes: Map[Int64, Place]): Result[String, List[Int64]] =
        let left = List.filter(segment -> not taken(segment, used), segments);
        if (List.isEmpty(left))
            Ok(ids)
        else
            match endPlace(nodes, ids) {
                case None => Err("the chain ended at a node the answer does not hold")
                case Some(stopped) =>
                    Err("ways left out of the chain: ${String.intercalate("; ", List.map(segment -> straggled(segment, stopped, nodes), left))}")
            }

    def straggled(segment: Segment, stopped: Place, nodes: Map[Int64, Place]): String = {
        let points = List.filterMap(id -> Map.get(id, nodes), segment#nodes);
        let gap = nearestGap(stopped, points);
        let near = gap < 0.5;
        let drive = if (not segment#oneway) "" else if (near) ", driven the other way" else ", oneway";
        let stands = if (near) "at" else "${Util.Format.fixed(1, gap)} m from";
        "${segment#id} is ${Util.Format.whole(Float64.round(polylineMetres(points)))} m, nearest end ${stands} where the chain stopped${drive}"
    }

    /// How far the nearer end of a way stands from where the chain stopped.
    def nearestGap(stopped: Place, points: List[Place]): Float64 =
        match (List.head(points), List.last(points)) {
            case (Some(first), Some(last)) => Float64.min(apart(stopped, first), apart(stopped, last))
            case _                         => 0.0
        }

    /// Whether the chained ids come back to the place they started from.
    def closes(nodes: Map[Int64, Place], ids: List[Int64]): Bool =
        match (startPlace(nodes, ids), endPlace(nodes, ids)) {
            case (Some(first), Some(last)) => samePlace(first, last)
            case _                         => false
        }

    /// The degrees are the equality the survey is measured on.
    def samePlace(a: Place, b: Place): Bool = a#lat == b#lat and a#lon == b#lon

    def startPlace(nodes: Map[Int64, Place], ids: List[Int64]): Option[Place] =
        Map.get(Option.getWithDefault(-1i64, List.head(ids)), nodes)

    def endPlace(nodes: Map[Int64, Place], ids: List[Int64]): Option[Place] =
        Map.get(Option.getWithDefault(-1i64, List.last(ids)), nodes)

    /// The distance between a lap's last place and its first, spelled for the sentence that
    /// refuses a lap which does not come back to where it started. A place the answer does
    /// not hold is named as nothing rather than measured from the zero of the map.
    def unclosed(nodes: Map[Int64, Place], ids: List[Int64]): String =
        match (endPlace(nodes, ids), startPlace(nodes, ids)) {
            case (Some(last), Some(to)) => Util.Format.fixed(1, apart(last, to))
            case _                      => "nothing"
        }

    /// The ids turned to start at the line the lap is measured from, which is where the lap's
    /// own zero stands.
    def rotate(ids: List[Int64], start: Int64): List[Int64] =
        match indexWhere(id -> id == start, ids, 0) {
            case None     => ids
            case Some(at) => List.append(List.drop(at, ids), List.take(at, ids))
        }

    def indexWhere(matching: Int64 -> Bool, ids: List[Int64], at: Int32): Option[Int32] =
        match ids {
            case Nil => None
            case one :: rest => if (matching(one)) Some(at) else indexWhere(matching, rest, at + 1)
        }

    // --------------------------------------------------- metres, direction, thinning

    /// The answer's degrees into the drawing's metres: one parallel for both lines, the lap
    /// stretched to the length the circuit publishes, the direction the survey runs, and the
    /// line thinned to what a drawing at a tenth of a metre cannot show.
    def laidOut(reading: Answer, nodes: Map[Int64, Place], lap: List[Int64], pit: List[Int64], circuit: Circuit): Geometry = {
        let lapNodes = List.filterMap(id -> Map.get(id, nodes), lap);
        let pitNodes = List.filterMap(id -> Map.get(id, nodes), pit);
        let both = List.append(lapNodes, pitNodes);
        let parallel = parallelOf(both);
        let lapPoints = List.map(projectOn(parallel), lapNodes);
        let pitPoints = List.map(projectOn(parallel), pitNodes);
        let surveyed = cumulative(lapPoints);
        let stretch = circuit#lap / Option.getWithDefault(0.0, List.last(surveyed));
        let metres = List.map(each -> each * stretch, surveyed);
        // The published metre each surveyed place stands at, in one list: the degrees
        // and the metre are one pair from here on, and never looked up apart.
        let lapMetres = Geodesy.together(lapNodes, metres);
        let half = List.length(lapPoints) / 2;
        let kept = thinned(lapPoints, half);
        let keptPit = simplify(pitPoints, 0, lastIndex(pitPoints));
        {
            centreline = List.map(at -> metred(at, lapMetres), kept),
            pitLane = List.filterMap(at -> List.nth(at, pitNodes), keptPit),
            frame = {origin = northWest(both), parallel = parallel},
            direction = turnDirection(lapPoints),
            surveyedAt = reading#surveyedAt,
            surveyedLength = Some(Option.getWithDefault(0.0, List.last(surveyed)))
        }
    }

    /// One kept point: the degrees it was surveyed at, and the published metre it stands
    /// at — both from the one place the lap's zipped metres are looked up at. A kept
    /// index runs over `lapPoints`, which is `lapMetres` projected, so every index lands.
    def metred(at: Int32, lap: List[Geodesy.Metred]): Geodesy.Metred =
        match List.nth(at, lap) {
            case Some(each) => {place = each#place, metre = roundTenth(each#metre)}
            case None       => {place = {lat = 0.0, lon = 0.0}, metre = 0.0}
        }

    /// The lap thinned: split at its own middle, so that the place the lap starts and ends at
    /// is not the pivot of both halves at once, and the halves joined at their meeting point
    /// rather than holding it twice.
    def thinned(points: List[Point], half: Int32): List[Int32] =
        List.append(withoutLast(simplify(points, 0, half)), simplify(points, half, lastIndex(points)))

    /// Ramer–Douglas–Peucker over indices, so a kept point keeps the distance it was
    /// surveyed at rather than the shorter one the thinned line would give it. Of two
    /// points equally far, the first is the one turned on.
    pub def simplify(points: List[Point], lo: Int32, hi: Int32): List[Int32] =
        match (List.nth(lo, points), List.nth(hi, points)) {
            case (Some(a), Some(b)) =>
                let dx = b#x - a#x;
                let dy = b#y - a#y;
                let norm = hypot(dx, dy);
                match furthest(points, hi, a, b, dx, dy, norm, 0.0, -1, lo + 1) {
                    case (best, at) =>
                        if (best <= tolerance() or at < 0) lo :: hi :: Nil
                        else List.append(withoutLast(simplify(points, lo, at)), simplify(points, at, hi))
                }
            case _ => Nil
        }

    /// The point of the stretch furthest from the line joining its ends, and how far it
    /// stands: the distance is the cross product over the line's own length, which is the
    /// height of the triangle and not the hypotenuse of anything.
    def furthest(
        points: List[Point],
        hi: Int32,
        a: Point,
        b: Point,
        dx: Float64,
        dy: Float64,
        norm: Float64,
        best: Float64,
        at: Int32,
        every: Int32
    ): (Float64, Int32) =
        if (every >= hi)
            (best, at)
        else
            match List.nth(every, points) {
                case None => (best, at)
                case Some(p) =>
                    let distance = offLine(p, a, b, dx, dy, norm);
                    if (distance > best)
                        furthest(points, hi, a, b, dx, dy, norm, distance, every, every + 1)
                    else
                        furthest(points, hi, a, b, dx, dy, norm, best, at, every + 1)
            }

    def offLine(p: Point, a: Point, b: Point, dx: Float64, dy: Float64, norm: Float64): Float64 =
        if (norm == 0.0)
            hypot(p#x - a#x, p#y - a#y)
        else
            Float64.abs((dy * p#x) - (dx * p#y) + (b#x * a#y) - (b#y * a#x)) / norm

    /// Which way the closed line runs, from the shoelace sum in the drawing's own metres:
    /// positive is clockwise, because this projection's `y` runs south.
    pub def turnDirection(points: List[Point]): String =
        if (shoelace(points) > 0.0) clockwise() else counterClockwise()

    def shoelace(points: List[Point]): Float64 =
        List.foldLeft(
            (total, pair) -> match pair {
                case (a, b) => total + ((a#x * b#y) - (b#x * a#y))
            },
            0.0,
            List.zip(points, List.append(List.drop(1, points), List.take(1, points)))
        )

    // --------------------------------------------------------------- the lists at hand

    def paired(pairs: List[(k, v)]): Map[k, v] with Order[k] =
        List.foldLeft((held, pair) -> match pair {case (key, value) => Map.insert(key, value, held)}, Map.empty(), pairs)

    /// Everything but the last of a list, so a line joined to another at their meeting
    /// point holds that point once.
    def withoutLast(points: List[a]): List[a] =
        Option.getWithDefault(Nil, List.init(points))

    def lastIndex(points: List[a]): Int32 =
        Int32.max(0, List.length(points) - 1)

    // --------------------------------------------------------------- the survey word

    /// One circuit, the answer it is surveyed from, and whether the file is laid down.
    /// `named` says whether the answer was named on the command line or taken from the
    /// circuit's directory, which is what tells a missing survey from an unreadable one.
    pub type alias Request = {
        circuit = Circuit,
        answer  = String,
        named   = Bool,
        fetch   = Bool,
        write   = Bool
    }

    pub def parse(args: List[String]): Result[ArgsError, Request] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  => completed(scanned)
        }

    def completed(scanned: Cli.Args.Scanned[Setting]): Result[ArgsError, Request] =
        complete(
            scanned#words,
            Cli.Args.lastNamed(answerNamed, scanned#options),
            List.exists(isFetched, scanned#options),
            List.exists(isWriting, scanned#options)
        )

    enum Setting with Eq {
        case Answer(String)
        case Fetch
        case Help
        case Writing
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
            argDescriptor = ArgDescr.NoArg(Setting.Writing),
            explanation   = "lay the geometry file down instead of answering whether\nthe survey still draws the kept bytes"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    /// A flag is no file: `--answer --write` is a reader who meant something else,
    /// and a survey that read it as a path would report a file that cannot be
    /// opened rather than an argument it was not given. GetOpt hands the argument
    /// over as it came; it is the completing that refuses one.
    def complete(named: List[String], answer: Option[String], fetch: Bool, write: Bool): Result[ArgsError, Request] =
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
                                    named = Option.nonEmpty(answer),
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

    def isWriting(setting: Setting): Bool =
        match setting {
            case Setting.Writing => true
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
    pub def arguments(args: List[String]): Cli.Args.Parsed[Request] =
        Cli.Args.prepare(optionDescrs(), usage(), isHelp, completed, args)

    /// The asking: the answer read — from a runner, from the file `--answer` names,
    /// or from the answer the circuit keeps — surveyed once, kept where a runner gave
    /// it, and then laid or compared however `--write` says.
    pub def asking(asked: Request): Outcome \ { IO, Clock, Console } =
        match answerText(asked) {
            case Err(problem)      => Outcome.Failed("${problem}")
            case Ok(None)          => Outcome.Done(neverSurveyed(asked) :: Nil)
            case Ok(Some(spelled)) =>
                Cli.Args.outcomeOf(
                    forM(
                        read <- surveyed(asked, spelled);
                        _    <- if (asked#fetch) keep(asked, read) else Ok(())
                    ) yield laid(asked, Geometry.Write.file(asked#circuit, read#geometry))
                )
        }

    /// Where a run's answer comes from. Finding nothing is the one reading with two
    /// right answers, which is why it comes back as `None` and not as a failure:
    /// `--answer` naming nothing is a mistake to report, while a circuit with no kept
    /// answer and no served geometry has simply never been surveyed.
    def answerText(asked: Request): Result[CliError, Option[String]] \ { IO, Clock } =
        if (asked#fetch)
            Overpass.askRelation(asked#circuit#relation)
                |> Result.mapErr(problem -> CliError.Reading("${asked#circuit#word}: ${problem}"))
                |> Result.map(spelled -> Some(spelled))
        else
            match Util.Files.exists(asked#answer) {
                case Err(problem) => Err(CliError.Reading("${asked#answer}: ${problem}"))
                case Ok(false)    =>
                    if (asked#named)
                        Err(CliError.Reading("${asked#answer}: no answer to read there"))
                    else
                        unexamined(asked)
                case Ok(true) =>
                    Cli.Errors.readFile(asked#answer)
                        |> Result.map(spelled -> Some(spelled))
            }

    /// Which of the two a circuit with no answer to read is. A served file says the
    /// bytes have no answer left to re-survey them from — which is what the fence
    /// exists to catch — and no served file says nobody has surveyed this circuit yet.
    def unexamined(asked: Request): Result[CliError, Option[String]] \ IO =
        match Util.Files.exists(asked#circuit#file) {
            case Err(problem) => Err(CliError.Reading("${asked#circuit#word}: ${problem}"))
            case Ok(true)     => Err(CliError.Reading("${asked#circuit#word}: ${asked#circuit#file} is served but ${asked#answer} is not kept — these bytes have no answer left to re-survey them from"))
            case Ok(false)    => Ok(None)
        }

    def neverSurveyed(asked: Request): String =
        "${asked#circuit#word}: no kept answer yet — asking OpenStreetMap is `--fetch`'s"

    /// The survey every answer travels through, however its text arrived, which is
    /// what makes a live survey and a comparison of a kept one fail and reproduce in
    /// the same words. One reading of the text serves both the keeping and the
    /// laying, so a runner's HTML page, a reply stopped half way through its JSON and
    /// an answer whose relation will not chain into a lap are each met in the words
    /// the survey itself would say them in, rather than in a file kept to be
    /// discovered later.
    def surveyed(asked: Request, spelled: String): Result[CliError, Read] =
        match geometry(spelled, asked#circuit) {
            case Ok(read) => Ok(read)
            case Err(problem) =>
                if (asked#fetch)
                    Err(CliError.Reading("${asked#answer}: the answer surveys nothing: ${problem}"))
                else
                    Err(CliError.Reading("${asked#answer}: ${problem}"))
        }

    /// `--fetch`'s keeping: the answer where `--answer` points — the circuit's own
    /// directory when it names none — and the line naming how big an answer it is. It
    /// is asked once the survey has read the text and before anything is laid, since
    /// an answer that surveys nothing is evidence nobody can re-run.
    def keep(asked: Request, read: Read): Result[CliError, Unit] \ { IO, Console } =
        Cli.Errors.writeFile(asked#answer, read#text)
            |> Result.map(_ -> Console.println(keptLine(asked, read#answer)))

    /// What the asking left beside the circuit.
    def keptLine(asked: Request, reading: Answer): String =
        let elements = Int32.toString(List.length(reading#elements));
        let stamp = match reading#surveyedAt {
            case None     => ""
            case Some(at) => ", surveyed at ${at}"
        };
        "${asked#circuit#word}: kept an answer of ${elements} elements${stamp} at ${asked#answer}"

    /// The file laid down, or the kept one asked for and laid against what the survey
    /// draws.
    def laid(asked: Request, written: String): Outcome \ IO =
        if (asked#write)
            laidDown(asked, written)
        else
            match Util.Files.exists(asked#circuit#file) {
                case Err(problem) => Outcome.Failed(problem)
                case Ok(false)    => Outcome.Failed("${asked#circuit#file}: no geometry to compare against — --write lays one")
                case Ok(true) =>
                    match Cli.Errors.readFile(asked#circuit#file) {
                        case Err(problem)  => Outcome.Failed("${problem}")
                        case Ok(served)    => against(asked, written, served)
                    }
            }

    def laidDown(asked: Request, written: String): Outcome \ IO =
        match Cli.Errors.writeFile(asked#circuit#file, written) {
            case Err(problem) => Outcome.Failed("${problem}")
            case Ok(_)        => Outcome.Done("${asked#circuit#word}: geometry written from ${asked#answer}" :: Nil)
        }

    /// Whether the bytes the survey draws are the bytes the app serves. That they are
    /// not is the answer the run was asked for rather than a run that failed, so it is
    /// said on stdout and exits 1.
    def against(asked: Request, written: String, served: String): Outcome =
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
