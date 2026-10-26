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
    use Apart.Point
    use Cli.Args.ArgsError
    use Geometry.Line
    use Geometry.Place
    use Sys.Console
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    /// The width the overlay is drawn at and the margin it is drawn inside. Fixed,
    /// so an overlay that outlives its files can be laid against the next run's;
    /// one that resized itself to its contents would make a changed line look like
    /// a moved one.
    pub def width(): Float64 = 1000.0

    def margin(): Float64 = 20.0

    /// The two lines' colours, in the order the files are named.
    def colours(): List[String] =
        "#d43a3a" :: "#2a6df4" :: Nil

    /// Two files, a spacing, and an overlay to write.
    pub type alias Args = {
        paths = List[String],
        every = Float64,
        svg   = Option[String]
    }

    /// What the command asks for: two files, a spacing over nought metres, and an
    /// overlay to write. Paths are used as they stand.
    pub def parse(args: List[String]): Result[ArgsError, Args] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  =>
                complete(
                    scanned#words,
                    Cli.Args.lastNamed(everyNamed, scanned#options),
                    Cli.Args.lastNamed(svgNamed, scanned#options)
                )
        }

    enum Setting {
        case Every(String)
        case Svg(String)
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
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

    def complete(paths: List[String], every: Option[String], svg: Option[String]): Result[ArgsError, Args] =
        if (List.length(paths) != 2)
            Err(ArgsError.ParseErrors(usage() :: Nil))
        else
            match spacing(every) {
                case Err(problem) => Err(ArgsError.ParseErrors(problem :: Nil))
                case Ok(metres)   => Ok({paths = paths, every = metres, svg = svg})
            }

    /// The word the reader typed is the word quoted back, which is what a reader can
    /// correct: a coerced number echoes a value they never wrote.
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
        match parse(args) {
            case Err(problem) =>
                Console.eprintln("${problem}");
                1
            case Ok(asked) =>
                match read(Nil, asked#paths) {
                    case Err(problem) =>
                        Console.eprintln("${problem}");
                        1
                    case Ok(lines) => report(lines, asked)
                }
        }

    /// Each file read as the line it claims to be, under the name the file is known by —
    /// `le_mans` for `app/static/geometry/le_mans.geojson`, which is the name the drawing,
    /// the config and the kept Overpass answer all use for the circuit.
    def read(kept: List[Line], paths: List[String]): Result[String, List[Line]] \ IO =
        match paths {
            case Nil => Ok(List.reverse(kept))
            case one :: more =>
                match Util.Files.read(one) {
                    case Err(problem) => Err("${one}: ${problem}")
                    case Ok(text) =>
                        match Geometry.outline(text, baseName(one)) {
                            case Err(problem) => Err(problem)
                            case Ok(line)     => read(line :: kept, more)
                        }
                }
        }

    /// The name a file is quoted by: its last path part, without the extension the profile
    /// writes it with.
    pub def baseName(path: String): String =
        Option.getWithDefault("", Option.map(withoutExtension, List.last(String.splitOn({substr = "/"}, path))))

    def withoutExtension(name: String): String =
        if (String.endsWith({suffix = ".geojson"}, name))
            String.dropRight(8, name)
        else
            name

    /// The report: what each file says it is, then each line sampled against the other,
    /// then the overlay if one was asked for.
    def report(lines: List[Line], args: Args): Int32 \ { IO, Console } = {
        let projected = projectedOf(lines);
        List.forEach(line -> Console.println(quoted(line)), lines);
        match (compared(lines, projected, 0, 1, args#every), compared(lines, projected, 1, 0, args#every)) {
            case (Ok(one), Ok(two)) =>
                Console.println(said(0, lines, one, args#every));
                Console.println(said(1, lines, two, args#every));
                overlaid(lines, projected, args#svg)
            case (Err(problem), _) =>
                Console.eprintln("${problem}");
                1
            case (_, Err(problem)) =>
                Console.eprintln("${problem}");
                1
        }
    }

    /// Both lines on one plane: the parallel they are projected about is the mean
    /// latitude of every place of both, so neither line is drawn at a scale of its own.
    def projectedOf(lines: List[Line]): List[List[Point]] = {
        let parallel = Apart.parallelOf(List.flatMap(line -> line#coords, lines));
        List.map(line -> List.map(Apart.projectOn(parallel), line#coords), lines)
    }

    def overlaid(lines: List[Line], projected: List[List[Point]], svg: Option[String]): Int32 \ { IO, Console } =
        match svg {
            case None => 0
            case Some(path) =>
                match Util.Files.write(path, overlay(lines, projected)) {
                    case Err(problem) =>
                        Console.eprintln("${path}: ${problem}");
                        1
                    case Ok(_) =>
                        Console.println("overlay: ${path}");
                        0
                }
        }

    /// What a line is, as its own file says: which kind of line, how far its own measure
    /// runs, and where it came from.
    pub def quoted(line: Line): String = {
        let cameFrom = match line#props#source {
            case None      => ""
            case Some(one) => " — ${one}"
        };
        "${line#name}: basis ${line#props#basis}, ${Util.Format.fixed(1, endsAt(line))} m${cameFrom}"
    }

    def endsAt(line: Line): Float64 =
        Option.getWithDefault(0.0, List.last(line#metres))

    /// One direction of the comparison.
    def compared(lines: List[Line], projected: List[List[Point]], along: Int32, against: Int32, every: Float64): Result[String, Apartness] =
        Apart.apartness(
            pointsOf(along, projected),
            metresOf(along, lines),
            pointsOf(against, projected),
            metresOf(against, lines),
            every
        )

    def pointsOf(at: Int32, projected: List[List[Point]]): List[Point] =
        Option.getWithDefault(Nil, List.nth(at, projected))

    def metresOf(at: Int32, lines: List[Line]): List[Float64] =
        Option.getWithDefault(Nil, Option.map(line -> line#metres, List.nth(at, lines)))

    /// One direction of the comparison as the sentence the report prints it in. Both
    /// directions are printed: they disagree when one line has places the other has not.
    pub def said(at: Int32, lines: List[Line], apart: Apartness, every: Float64): String =
        "sampled every ${Util.Format.spelled(every)} m along ${nameOf(at, lines)} (${apart#count}): "
            + "mean apart ${Util.Format.fixed(1, apart#mean)} m, "
            + "max ${Util.Format.fixed(1, apart#worst#distance)} m at ${Util.Format.fixed(0, apart#worst#aMetres)} m, "
            + "our-side ${Util.Format.fixed(1, apart#worst#bMetres)} m"

    def nameOf(at: Int32, lines: List[Line]): String =
        Option.getWithDefault("nothing", Option.map(line -> line#name, List.nth(at, lines)))

    // ------------------------------------------------------------------- the overlay

    /// The drawing both lines are laid on: how far north-west they start, how far they
    /// reach from there, and the one scale both are drawn at.
    pub type alias View = {
        origin = Point,
        reach  = Point,
        scale  = Float64
    }

    def viewOf(projected: List[List[Point]]): View = {
        let origin = cornerOf(projected);
        let reach = reachOf(origin, projected);
        {origin = origin, reach = reach, scale = (width() - (2.0 * margin())) / widest(reach)}
    }

    /// The north-west corner of both lines together — the first place they were
    /// measured at, not the zero of the plane, which is a place neither line passes
    /// and a drawing framed by it would leave the lines in one corner of it.
    def cornerOf(projected: List[List[Point]]): Point =
        match flatten(projected) {
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
    def reachOf(origin: Point, projected: List[List[Point]]): Point =
        List.foldLeft(
            (reach, place) -> {
                x = if (place#x - origin#x > reach#x) place#x - origin#x else reach#x,
                y = if (place#y - origin#y > reach#y) place#y - origin#y else reach#y
            },
            {x = 0.0, y = 0.0},
            flatten(projected)
        )

    def flatten(projected: List[List[Point]]): List[Point] =
        List.flatMap(places -> places, projected)

    /// The axis the drawing is fitted to, which is the one that needs the most room:
    /// fitting the other would run the line off the page.
    def widest(reach: Point): Float64 =
        if (reach#x >= reach#y) reach#x else reach#y

    /// Both lines as one drawing, with the provenance each file carries written into it
    /// as its own comment: an overlay that outlives its files says what it was comparing,
    /// and what each of them was licensed under.
    pub def overlay(lines: List[Line], projected: List[List[Point]]): String = {
        let view = viewOf(projected);
        let page = Util.Format.whole(width());
        let across = Util.Format.fixed(0, (2.0 * margin()) + (view#reach#y * view#scale));
        String.intercalate(
            "\n",
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                :: "<!-- Geometry overlay: ${nameOf(0, lines)} in red against ${nameOf(1, lines)} in blue."
                :: "${licensed(lines)} -->"
                :: provenance(lines)
                :: "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${page}\" height=\"${across}\" viewBox=\"0 0 ${page} ${across}\">"
                :: "  <rect width=\"100%\" height=\"100%\" fill=\"white\"/>"
                :: drawn(lines, projected, view)
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
    def drawn(lines: List[Line], projected: List[List[Point]], view: View): String =
        strokes(Nil, lines, projected, colours(), view) |> String.intercalate("\n")

    def strokes(
        kept: List[String],
        lines: List[Line],
        projected: List[List[Point]],
        tints: List[String],
        view: View
    ): List[String] =
        match (lines, projected, tints) {
            case (_line :: more, places :: rest, colour :: further) =>
                strokes(
                    "  <path d=\"M ${String.intercalate(" L ", List.map(point -> placed(view, point), places))}\" fill=\"none\" stroke=\"${colour}\" stroke-width=\"2\" opacity=\"0.8\"/>"
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
