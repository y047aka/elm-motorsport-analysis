/// Lays any two geometries of this repository's profile against each other and says, in
/// metres, where they disagree — optionally as an SVG overlay.
///
///     nix run .#geometry -- diff app/static/geometry/le_mans.geojson circuits/le_mans/atlas.geojson
///
/// The only claim a file must keep is the one the profile makes of its outline: a line with
/// metres measured from its own lap's zero. The basis is free — this is the reading that
/// compares a survey to a measurement, or a survey to the same survey a year later — and the
/// report quotes each file's own `basis` and `source` beside every figure, so an output cannot
/// be read as two files agreeing when only one line was kept.
///
/// `Geometry` is that reading and `Apart` the comparison; this is the asking of two files,
/// the printing, and the drawing.
pub mod Diff {

    use Apart.Apartness
    use Geodesy.Point
    use Cli.Args.ArgsError
    use Cli.Args.Outcome
    use Geometry.Line
    use Geodesy.Place
    use Sys.Console
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    /// The width the overlay is drawn at and the margin it is drawn inside. Fixed,
    /// so an overlay that outlives its files can be laid against the next run's.
    pub def width(): Float64 = 1000.0

    def margin(): Float64 = 20.0

    /// The two lines' colours, in the order the files are named.
    def colours(): List[String] =
        "#d43a3a" :: "#2a6df4" :: Nil

    /// Two files, a spacing, and an overlay to write. The files are a pair because
    /// the report compares one against the other and back: the order they are named
    /// in is the order the report walks them.
    pub type alias Request = {
        a     = String,
        b     = String,
        every = Float64,
        svg   = Option[String]
    }

    /// What the command asks for: two files, a spacing over nought metres, and an
    /// overlay to write. Paths are used as they stand.
    pub def parse(args: List[String]): Result[ArgsError, Request] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  => completed(scanned)
        }

    def completed(scanned: Cli.Args.Scanned[Setting]): Result[ArgsError, Request] =
        complete(
            scanned#words,
            Cli.Args.lastNamed(everyNamed, scanned#options),
            Cli.Args.lastNamed(svgNamed, scanned#options)
        )

    enum Setting with Eq {
        case Help
        case Every(String)
        case Svg(String)
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
        Cli.Args.helpDescr(Setting.Help) ::
        {
            optionIds     = Nil,
            optionNames   = "every" :: Nil,
            argDescriptor = ArgDescr.ReqArg(metres -> Some(Setting.Every(metres)), "METRES"),
            explanation   = "how far apart the samples stand along each line\n(default ${Apart.defaultEvery()} m)"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "svg" :: Nil,
            argDescriptor = ArgDescr.ReqArg(path -> Some(Setting.Svg(path)), "OUT.SVG"),
            explanation   = "draw the two lines over each other into this file"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    /// The word the reader typed is the word quoted back.
    def complete(paths: List[String], every: Option[String], svg: Option[String]): Result[ArgsError, Request] =
        match paths {
            case one :: two :: Nil =>
                match spacing(every) {
                    case Err(problem) => Err(ArgsError.ParseErrors(problem :: Nil))
                    case Ok(metres)   => Ok({a = one, b = two, every = metres, svg = svg})
                }
            case _ => Err(ArgsError.ParseErrors("diff lays two files, and no more: ${List.length(paths)} named." :: Nil))
        }

    def spacing(every: Option[String]): Result[String, Float64] =
        match every {
            case None => Ok(Apart.defaultEvery())
            case Some(spelled) =>
                match Float64.fromString(spelled) {
                    case Some(metres) if metres > 0.0 => Ok(metres)
                    case Some(metres) => Err("\"${Util.Format.spelled(metres)}\" is not a distance")
                    case None         => Err("\"${spelled}\" is not a distance")
                }
        }

    def everyNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.Every(metres) => Some(metres)
            case _                     => None
        }

    def svgNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.Svg(path) => Some(path)
            case _                 => None
        }

    /// The sentence for anything the walk could not use; two files are wanted, and no more.
    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "usage: nix run .#geometry -- diff <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]",
            optionDescrs()
        )

    // ------------------------------------------------------------------- the command

    /// The exit code the report comes to: 1 for arguments it cannot ask with, for a file
    /// it cannot read or that is not a geometry of this profile, and for an overlay it
    /// could not write.
    pub def exitCode(args: List[String]): Int32 \ { IO, Console } =
        Cli.Args.comeTo(arguments(args), asking)

    /// The arguments as far as the flag table reads them, before the report asks which
    /// two files were named.
    pub def arguments(args: List[String]): Cli.Args.Parsed[Request] =
        Cli.Args.prepare(optionDescrs(), usage(), isHelp, completed, args)

    /// Both files read as the lines they claim to be, and reported. The reading that
    /// failed is the run that never got to a verdict; the diff itself only ever says
    /// metres, leaving whether they are far to the reader.
    def asking(asked: Request): Outcome \ { IO, Console } =
        match forM(
            one <- read(asked#a);
            two <- read(asked#b)
        ) yield (one, two) {
            case Err(problem) => Outcome.Failed(problem)
            case Ok(lines)    => reported(lines, asked) |> Cli.Args.outcomeOf
        }

    /// A file read as the line it claims to be, under the name the file is known by —
    /// `le_mans` for `app/static/geometry/le_mans.geojson`, which is the name the
    /// drawing, the config and the kept Overpass answer all use for the circuit.
    def read(path: String): Result[String, Line] \ IO =
        Cli.Errors.readFile(path)
            |> Result.mapErr(problem -> "${problem}")
            |> Result.flatMap(Geometry.outline(baseName(path)))

    /// The name a file is quoted by: its last path part, without the extension the
    /// profile writes it with.
    pub def baseName(path: String): String =
        path |> Circuit.lastPart |> withoutExtension

    def withoutExtension(name: String): String =
        if (String.endsWith({suffix = Geometry.extension()}, name))
            name |> String.dropRight(String.length(Geometry.extension()))
        else
            name

    /// The report: what each file says it is, then each line sampled against the other,
    /// then the overlay if one was asked for.
    def reported(lines: (Line, Line), asked: Request): Result[String, Outcome] \ { IO, Console } = {
        let (first, second) = lines;
        match projectedOf(lines) {
            case Err(problem) => Err(problem)
            case Ok(projected) =>
                let (downFirst, downSecond) = projected;
                Console.println(quoted(first));
                Console.println(quoted(second));
                forM(
                    one <- Apart.apartness(downFirst, downSecond, asked#every);
                    two <- Apart.apartness(downSecond, downFirst, asked#every)
                ) yield spoken(lines, projected, one, two, asked)
        }
    }

    /// Both directions said, each as far round the lap as the other, and the overlay
    /// laid over them where the run asked for one.
    def spoken(
        lines: (Line, Line),
        projected: (List[Apart.Metred], List[Apart.Metred]),
        one: Apartness,
        two: Apartness,
        asked: Request
    ): Outcome \ { IO, Console } = {
        let (first, second) = lines;
        Console.println(said(first, one, asked#every));
        Console.println(said(second, two, asked#every));
        overlaid(lines, projected, asked#svg)
    }

    /// Both lines on one plane, projected about `Geodesy.parallelOf` — the mean
    /// latitude of both lines together — each place with the metre of its line's own
    /// measure, which is all the sampling asks of a line. `Geometry` has refused any
    /// file whose metres do not stand one per point before one reached here, so the
    /// door below answers `Ok` for every line there is.
    def projectedOf(lines: (Line, Line)): Result[String, (List[Apart.Metred], List[Apart.Metred])] = {
        let (first, second) = lines;
        match Geodesy.parallelOf(first#coords ++ second#coords) {
            case None => Err("${first#name} and ${second#name} hold no places between them to project")
            case Some(parallel) =>
                let onto = line -> Apart.line(List.map(Geodesy.projectOn(parallel), line#coords), line#metres);
                match forM(
                    one <- onto(first);
                    two <- onto(second)
                ) yield (one, two) {
                    case Ok(pair)     => Ok(pair)
                    case Err(problem) => Err(problem)
                }
        }
    }

    /// The overlay, written where it was asked for. A run that asked for none has
    /// already said everything it came to say.
    def overlaid(
        lines: (Line, Line),
        projected: (List[Apart.Metred], List[Apart.Metred]),
        svg: Option[String]
    ): Outcome \ IO =
        match svg {
            case None => Outcome.Done(Nil)
            case Some(path) =>
                match Cli.Errors.writeFile(path, overlay(lines, projected)) {
                    case Err(problem) => Outcome.Failed("${problem}")
                    case Ok(_)        => Outcome.Done("overlay: ${path}" :: Nil)
                }
        }

    /// What a line is, as its own file says: which kind of line, how far its own measure
    /// runs, and where it came from.
    pub def quoted(line: Line): String = {
        let cameFrom = match line#props#source {
            case None      => ""
            case Some(one) => " — ${one}"
        };
        "${line#name}: basis ${line#props#basis}, ${line |> endsAt |> Util.Format.fixed(1)} m${cameFrom}"
    }

    def endsAt(line: Line): Float64 =
        line#metres |> List.last |> Option.getWithDefault(0.0)

    /// One direction of the comparison as the sentence the report prints it in. Both
    /// directions are printed: they disagree when one line has places the other has not.
    pub def said(line: Line, apart: Apartness, every: Float64): String =
        "sampled every ${Util.Format.spelled(every)} m along ${line#name} (${apart#count}): "
            + "mean apart ${Util.Format.fixed(1, apart#mean)} m, "
            + "max ${Util.Format.fixed(1, apart#worst#distance)} m at ${Util.Format.fixed(0, apart#worst#aMetres)} m, "
            + "our-side ${Util.Format.fixed(1, apart#worst#bMetres)} m"

    // ------------------------------------------------------------------- the overlay

    /// The drawing both lines are laid on: how far north-west they start, how far they
    /// reach from there, and the one scale both are drawn at.
    pub type alias View = {
        origin = Point,
        reach  = Point,
        scale  = Float64
    }

    def viewOf(projected: List[List[Apart.Metred]]): View = {
        let origin = cornerOf(projected);
        let reach = reachOf(origin, projected);
        {origin = origin, reach = reach, scale = (width() - (2.0 * margin())) / widest(reach)}
    }

    /// The north-west corner of both lines together — the first place they were
    /// measured at, not the zero of the plane.
    def cornerOf(projected: List[List[Apart.Metred]]): Point =
        match List.flatMap(points, projected) {
            case Nil => {x = 0.0, y = 0.0}
            case first :: rest =>
                List.foldLeft(
                    (corner, place) -> {
                        x = if (place#x < corner#x) place#x else corner#x,
                        y = if (place#y < corner#y) place#y else corner#y
                    },
                    first,
                    rest
                )
        }

    /// How far the lines reach east and south from that corner.
    def reachOf(origin: Point, projected: List[List[Apart.Metred]]): Point =
        List.foldLeft(
            (reach, place) -> {
                x = if (place#x - origin#x > reach#x) place#x - origin#x else reach#x,
                y = if (place#y - origin#y > reach#y) place#y - origin#y else reach#y
            },
            {x = 0.0, y = 0.0},
            List.flatMap(points, projected)
        )

    /// The places of a sampled line — the drawing reads the metres from the file, not
    /// from the line's measure.
    def points(line: List[Apart.Metred]): List[Point] =
        List.map(each -> each#point, line)

    /// The axis the drawing is fitted to, which is the one that needs the most room:
    /// fitting the other would run the line off the page.
    def widest(reach: Point): Float64 =
        if (reach#x >= reach#y) reach#x else reach#y

    /// Both lines as one drawing, with the provenance each file carries written into it
    /// as its own comment: an overlay that outlives its files says what it was comparing,
    /// and what each of them was licensed under.
    pub def overlay(lines: (Line, Line), projected: (List[Apart.Metred], List[Apart.Metred])): String = {
        let (first, second) = lines;
        let (firstPlaces, secondPlaces) = projected;
        let both = first :: second :: Nil;
        let places = firstPlaces :: secondPlaces :: Nil;
        let view = viewOf(places);
        let page = Util.Format.whole(width());
        let across = Util.Format.fixed(0, (2.0 * margin()) + (view#reach#y * view#scale));
        String.intercalate(
            "\n",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                :: "<!-- Geometry overlay: ${first#name} in red against ${second#name} in blue."
                :: "${licensed(both)} -->"
                :: provenance(both)
                :: "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${page}\" height=\"${across}\" viewBox=\"0 0 ${page} ${across}\">"
                :: "  <rect width=\"100%\" height=\"100%\" fill=\"white\"/>"
                :: drawn(both, places, view)
                :: "</svg>" ::
                    // An empty last line: the drawing ends with a newline, as every kept file does.
                    ""
                        :: Nil
        )
    }

    /// One line, drawn, in the colour its place in the order the files were named in
    /// gives it. The files, their places and the colours are walked together rather
    /// than mapped over: `List.map3` is a cross product to Flix's `Applicative` rather
    /// than a zip, and would draw every line in every colour it was handed.
    def drawn(lines: List[Line], projected: List[List[Apart.Metred]], view: View): String =
        strokes(Nil, lines, projected, colours(), view) |> String.intercalate("\n")

    def strokes(
        kept: List[String],
        lines: List[Line],
        projected: List[List[Apart.Metred]],
        tints: List[String],
        view: View
    ): List[String] =
        match (lines, projected, tints) {
            case (_line :: more, places :: rest, colour :: further) =>
                strokes(
                    "  <path d=\"M ${String.intercalate(" L ", List.map(point -> placed(view, point), points(places)))}\" fill=\"none\" stroke=\"${colour}\" stroke-width=\"2\" opacity=\"0.8\"/>"
                        :: kept,
                    more,
                    rest,
                    further,
                    view
                )
            case _ => List.reverse(kept)
        }

    def placed(view: View, point: Point): String = {
        let east = margin() + ((point#x - view#origin#x) * view#scale);
        let north = margin() + ((view#origin#y + view#reach#y - point#y) * view#scale);
        "${Util.Format.fixed(1, east)},${Util.Format.fixed(1, north)}"
    }

    /// What each file says it is, as the drawing's own comment. A line with no source
    /// says so.
    def provenance(lines: List[Line]): String =
        List.map(
            line -> "  <!-- ${line#name}: ${line#props#basis} — ${Option.getWithDefault("no source", line#props#source)} -->",
            lines
        )
            |> String.intercalate("\n")

    /// The licenses the files carry, as a comment of their own.
    def licensed(lines: List[Line]): String =
        List.filterMap(
            line -> Option.map(licence -> "Data: ${line#name} is © under ${licence}.", line#props#license),
            lines
        )
            |> String.intercalate("\n")
}
