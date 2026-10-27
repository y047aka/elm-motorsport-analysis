/// The regeneration fence: re-run the pipeline over each circuit's kept Overpass
/// answer — the survey a kept geometry was judged from, kept as the runner served
/// it, whose degrees cannot move — and fail unless it reproduces the geometry the
/// app serves. Why that is the check no Elm test can be is `circuits/README.md`.
///
///     nix run .#geometry -- regenerate [<circuit> ...] [--write | --freeze]
///
/// A run over the answer that does not reproduce the geometry moved the degrees in
/// the code. `--write` re-lays the geometry files from the kept answer — where a
/// changed writer lands its bytes with no survey moved. `--freeze` asks
/// OpenStreetMap now and keeps the answer and the geometry as one reading; a
/// default run reaches the answer by no network at all, since a regeneration that
/// silently answered itself from the frozen survey would stop meaning what it says.
///
/// The comparison is of parsed properties and not of bytes — `-- survey`'s
/// comparison is of bytes and has nothing to exempt. What the fence answers for is
/// the drawing, and the writer's layout is allowed to change between the survey and
/// this reading, so `surveyed_at` stands outside the comparison: it stamps which
/// answer a file was written from rather than what the drawing is made of, and it
/// is the one property a live regeneration must move while every degree stands
/// still. Every other property is asked of both files, including ones no writer
/// claims, so a fence over a smaller file is no weaker than the file.
pub mod Regenerate {

    use Circuit.Circuit
    use Cli.Args.ArgsError
    use Cli.Args.Outcome
    use Sys.Console
    use Time.Clock
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr
    use Util.Json.Json

    /// What a run does with the survey: answer whether the kept geometry is what
    /// the kept answer draws, lay it down over the kept geometry, or ask
    /// OpenStreetMap fresh and keep both.
    pub enum Mode with Eq {
        case Compare
        case Write
        case Freeze
    }

    /// The circuits one run walks, and what it does with each.
    pub type alias Args = {
        circuits = List[Circuit],
        mode     = Mode
    }

    /// A feature of a geometry file: its members, JSON as the file's JSON gives them.
    /// The role that picks a feature out of a file lives inside its properties.
    type alias Feature = Map[String, Json]

    // ------------------------------------------------------------------- the command

    pub def parse(args: List[String]): Result[ArgsError, Args] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  => completed(scanned)
        }

    def completed(scanned: Cli.Args.Scanned[Setting]): Result[ArgsError, Args] =
        complete(scanned#words, List.exists(isWriting, scanned#options), List.exists(isFreeze, scanned#options))

    enum Setting with Eq {
        case Help
        case Writing
        case Freeze
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
        Cli.Args.helpDescr(Setting.Help) ::
        {
            optionIds     = Nil,
            optionNames   = "write" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.Writing),
            explanation   = "re-lay the geometry files from the kept answers"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "freeze" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.Freeze),
            explanation   = "ask OpenStreetMap now and keep the answer and the\ngeometry as one reading"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    def isWriting(setting: Setting): Bool =
        setting == Setting.Writing

    def isFreeze(setting: Setting): Bool =
        setting == Setting.Freeze

    def complete(named: List[String], write: Bool, freeze: Bool): Result[ArgsError, Args] =
        if (write and freeze)
            Err(ArgsError.ParseErrors("--write and --freeze ask for opposite things: the kept answer, and a fresh survey." :: Nil))
        else
            match picked(named) {
                case Err(problem) => Err(ArgsError.ParseErrors(problem :: Nil))
                case Ok(chosen) =>
                    Ok({
                        circuits = chosen,
                        mode = if (freeze) Mode.Freeze else if (write) Mode.Write else Mode.Compare
                    })
            }

    /// The circuits a run walks: the reader's own words in the order they typed
    /// them, or every circuit this project surveys. A word no circuit answers to
    /// fails the whole run before it walks any of them.
    def picked(words: List[String]): Result[String, List[Circuit]] =
        if (List.isEmpty(words))
            Ok(Circuit.circuits())
        else
            List.foldLeft(
                (chosen, word) -> match chosen {
                    case Err(problem) => Err(problem)
                    case Ok(surveyed) =>
                        match Circuit.byWord(word) {
                            case None          => Err(Circuit.unknown(word))
                            case Some(circuit) => Ok(surveyed ++ (circuit :: Nil))
                        }
                },
                Ok(Nil),
                words
            )

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "usage: nix run .#geometry -- regenerate [<circuit> ...] [--write | --freeze]",
            optionDescrs()
        )

    /// The exit code the fence comes to: 1 for a word no circuit answers to, two
    /// opposite flags, a run that could not ask, survey or write, and a drawing
    /// that moved.
    pub def exitCode(args: List[String]): Int32 \ { IO, Clock, Console } =
        Cli.Args.comeTo(arguments(args), asking)

    /// The arguments as far as the flag table reads them, before the fence asks which
    /// words answer to circuits.
    pub def arguments(args: List[String]): Cli.Args.Parsed[Args] =
        Cli.Args.prepare(optionDescrs(), usage(), isHelp, completed, args)

    /// Every circuit, in the order the reader named them — or every circuit this
    /// project surveys, named in the order it surveys them — each read and judged as
    /// it comes, so each verdict is printed while the circuits behind it are still
    /// being asked rather than all of them at the end. A circuit the run could not
    /// ask, survey or write ends the walk, since nothing about the run improved for
    /// the next circuit; a drawing that moved is a verdict and not a failure, so the
    /// circuits beside it have their own degrees to answer for.
    def asking(asked: Args): Outcome \ { IO, Clock, Console } = {
        warnUnlisted();
        Result.traverse(circuit -> check(circuit, asked#mode), asked#circuits)
            |> Result.map(verdictOf)
            |> Cli.Args.outcomeOf
    }

    /// Kept evidence and served geometry that answer to no config, printed as the
    /// CLI prints its unlisted CSVs — a warning that changes no verdict. Which
    /// circuits the run names changes nothing here: the disk holds what it holds.
    def warnUnlisted(): Unit \ { IO, Console } = {
        foreach (word <- unwordedEvidence())
            Console.eprintln("circuits/${word}: kept evidence for no circuit — is its word misspelled?");
        foreach (file <- undrawn())
            Console.eprintln("app/static/geometry/${file}: geometry no config draws")
    }

    /// Directories under `circuits/` that hold a kept answer or a kept atlas line
    /// under a name no config is authored for. A directory holding neither — the
    /// project's own sources among them — keeps no evidence, and says nothing.
    def unwordedEvidence(): List[String] \ IO =
        match Util.Files.list("circuits") {
            case Err(_)   => Nil
            case Ok(names) =>
                Regenerate.Unlisted.detect(
                    Regenerate.Unlisted.words(Circuit.circuits()),
                    List.filterMap(keepsEvidence, names)
                )
        }

    def keepsEvidence(name: String): Option[String] \ IO =
        if (String.startsWith({prefix = "."}, name))
            None
        else
            match Util.Files.list("circuits/${name}") {
                case Err(_)    => None
                case Ok(files) =>
                    if (List.exists(entry -> List.memberOf(entry, Regenerate.Unlisted.evidence()), files))
                        Some(name)
                    else
                        None
            }

    /// Geometry files in the served directory whose name no config's `file` is.
    def undrawn(): List[String] \ IO =
        match Util.Files.list("app/static/geometry") {
            case Err(_)    => Nil
            case Ok(files) =>
                Regenerate.Unlisted.detect(
                    Regenerate.Unlisted.drawn(Circuit.circuits()),
                    List.filter(file -> String.endsWith({suffix = ".geojson"}, file), files)
                )
        }

    /// One circuit's answer, as the walk leaves it, each one printed where it was
    /// found and none of them enough on its own for the exit code.
    enum Verdict with Eq {
        /// The kept geometry is what the kept answer draws.
        case Reproduced
        /// It is not: the verdict the fence is run in order to be able to say.
        case Drifted
        /// `--write` re-laid the file, which leaves nothing to judge.
        case Rewritten
        /// No kept answer to survey — a circuit never surveyed, not a failure.
        case Unsurveyed
    }

    def isDrifted(verdict: Verdict): Bool =
        verdict == Verdict.Drifted

    /// The walk over every circuit: a drawing that moved anywhere is the run's
    /// answer, and each drift was printed where it was found, so the exit code is all
    /// that is left to say.
    def verdictOf(verdicts: List[Verdict]): Outcome =
        if (List.exists(isDrifted, verdicts))
            Outcome.Verdict(Nil)
        else
            Outcome.Done(Nil)

    /// One circuit's verdict: `Drifted` where the drawing has moved,
    /// `Reproduced` where the kept geometry is what the kept answer draws, and a
    /// failure where the run itself did not happen.
    def check(circuit: Circuit, mode: Mode): Result[String, Verdict] \ { IO, Clock, Console } =
        match mode {
            case Mode.Freeze =>
                match Overpass.askRelation(circuit#relation) {
                    case Err(problem) => Err("${circuit#word}: ${problem}")
                    case Ok(answer)   => surveyed(circuit, answer, mode)
                }
            case _ =>
                match Util.Files.read(Circuit.keptAnswer(circuit)) {
                    case Err(_)     => skipped(circuit)
                    case Ok(answer) => surveyed(circuit, answer, mode)
                }
        }

    /// A circuit with no kept answer has not been surveyed yet, which is not a
    /// failure of a run over every circuit — the same reading `survey` makes of
    /// the same missing file, from the same reason.
    def skipped(circuit: Circuit): Result[String, Verdict] \ Console = {
        Console.println("${circuit#word}: no kept answer yet — --freeze asks OpenStreetMap and keeps one.");
        Ok(Verdict.Unsurveyed)
    }

    /// The answer surveyed, then what the mode says to do with the survey. The
    /// reading is the survey command's own, so a live survey and a fence over a
    /// kept answer fail in the same words.
    def surveyed(circuit: Circuit, answer: String, mode: Mode): Result[String, Verdict] \ { IO, Console } =
        match Survey.survey(answer, circuit) {
            case Err(problem)      => Err("${circuit#word}: ${problem}")
            case Ok((_, geometry)) => laid(circuit, Write.geoJson(circuit, geometry), answer, mode)
        }

    def laid(circuit: Circuit, written: String, answer: String, mode: Mode): Result[String, Verdict] \ { IO, Console } =
        match mode {
            // The answer is kept before the geometry is laid: a freeze keeps one
            // reading of OpenStreetMap, and a geometry whose answer did not reach disk
            // would be evidence for no future run.
            case Mode.Freeze =>
                match Cli.Errors.writeFile(Circuit.keptAnswer(circuit), answer) {
                    case Err(problem) => Err("${problem}")
                    case Ok(_)        => writing(circuit, written, "a fresh survey")
                }
            case Mode.Write   => writing(circuit, written, "the kept answer")
            case Mode.Compare => fenced(circuit, written)
        }

    def writing(circuit: Circuit, written: String, source: String): Result[String, Verdict] \ { IO, Console } =
        match Cli.Errors.writeFile(circuit#file, written) {
            case Err(problem) => Err("${problem}")
            case Ok(_) =>
                Console.println("${circuit#word}: geometry written from ${source}");
                Ok(Verdict.Rewritten)
        }

    /// The question the fence answers: is the kept geometry what the kept answer
    /// draws? Every drift is printed.
    def fenced(circuit: Circuit, written: String): Result[String, Verdict] \ { IO, Console } =
        match Util.Files.read(circuit#file) {
            case Err(problem) => Err("${circuit#file}: no geometry to compare against: ${problem}")
            case Ok(kept) =>
                match driftOf(written, kept) {
                    case Err(problem) => Err(problem)
                    case Ok(Nil) =>
                        Console.println("${circuit#word}: reproduces the kept geometry, every fenced property exactly");
                        Ok(Verdict.Reproduced)
                    case Ok(drift) =>
                        Console.println("${circuit#word}: the kept geometry is not what the kept answer draws");
                        foreach (line <- drift)
                            Console.println("  ${line}");
                        Ok(Verdict.Drifted)
                }
        }

    // ---------------------------------------------------------- the comparison

    /// The properties that answer for the drawing, in the order the writer lays
    /// them. `surveyed_at` is outside this list and outside the comparison: the
    /// fence's one exemption. A property a file carries that no writer claims is
    /// still asked of it, by `askedOf`.
    pub def compared(): List[String] =
        "role" :: "circuit" :: "basis" :: "source" :: "license" :: "direction" ::
        "lap_length_m" :: "surveyed_length_m" :: "sectors" :: "frame" :: "metres" :: Nil

    /// How one geometry file's data answers to another's, feature by feature and
    /// property by property: the reading the fence judges, stated without opening
    /// either file. `fresh` is what the survey would write, `kept` what the app
    /// serves; each drift line names the feature, the thing that moved, and what
    /// each side says.
    pub def driftOf(fresh: String, kept: String): Result[String, List[String]] =
        match (Util.Json.parse(fresh), Util.Json.parse(kept)) {
            case (Err(problem), _) => Err("the regenerated file does not parse: ${problem}")
            case (_, Err(problem)) => Err("the kept file does not parse: ${problem}")
            case (Ok(fromAnswer), Ok(fromFile)) =>
                let roles = held(Nil, rolesOf(fromAnswer) ++ rolesOf(fromFile));
                Ok(List.flatMap(role -> about(role, featuresOf(fromAnswer), featuresOf(fromFile)), roles))
        }

    /// The roles the two files hold, each named once, in the order the files hold
    /// them — the order the report walks.
    def held(seen: List[Option[String]], rest: List[Option[String]]): List[Option[String]] =
        match rest {
            case Nil         => seen
            case one :: more => held(if (List.memberOf(one, seen)) seen else seen ++ (one :: Nil), more)
        }

    def rolesOf(file: Json): List[Option[String]] =
        List.map(roleOf, featuresOf(file))

    def featuresOf(file: Json): List[Feature] =
        Geometry.featuresOf(file)

    def roleOf(feature: Feature): Option[String] =
        Geometry.word("role", Geometry.propertiesOf(feature))

    /// What a feature with no role is called in a drift line.
    def named(role: Option[String]): String =
        Option.getWithDefault("nothing", role)

    def about(role: Option[String], fresh: List[Feature], kept: List[Feature]): List[String] =
        let mine = List.filter(hasRole(role), fresh);
        let theirs = List.filter(hasRole(role), kept);
        match (List.head(mine), List.head(theirs)) {
            case (Some(one), Some(only)) => feature(named(role), one, only)
            case (Some(_), None)         => "${named(role)}: only the regeneration holds it" :: Nil
            case (None, Some(_))         => "${named(role)}: only the kept file holds it" :: Nil
            case (None, None)            => Nil
        }

    def hasRole(role: Option[String], feature: Feature): Bool =
        roleOf(feature) == role

    def feature(role: String, fresh: Feature, kept: Feature): List[String] =
        points(role, fresh, kept) ++ properties(role, fresh, kept)

    /// The degrees first: a line whose points differ is reported at the point it
    /// differs at. A difference in anything else the geometry member holds — its
    /// type, a coordinate that is not a pair — is reported too, at the point its
    /// coordinates part, or at -1 where they do not and only the shape moved.
    def points(role: String, fresh: Feature, kept: Feature): List[String] =
        if (same(geometryOf(fresh), geometryOf(kept)))
            Nil
        else
            "${role}: the line's points differ at point ${firstDiff(coordinatesOf(fresh), coordinatesOf(kept))}" :: Nil

    /// Each property the pair is asked about, in the order the fence asks — the
    /// writer's claims in the writer's order, then whatever else either file
    /// carries. A property one side holds and the other does not is drift, quoted
    /// as `absent` on the side that holds nothing.
    def properties(role: String, fresh: Feature, kept: Feature): List[String] =
        let mine = Geometry.propertiesOf(fresh);
        let theirs = Geometry.propertiesOf(kept);
        List.foldLeft(
            (drift, key) ->
                match (Map.get(key, mine), Map.get(key, theirs)) {
                    case (one, only) =>
                        if (sameOption(one, only))
                            drift
                        else
                            drift ++ ("${role}: ${key} is ${shown(only)} in the file, ${shown(one)} from the answer" :: Nil)
                },
            Nil,
            askedOf(mine, theirs)
        )

    /// Which properties a pair is asked about. The claimed ones first, in the
    /// order the writer lays them, so the report reads like the file; then any
    /// other key either file carries, which is an added claim or one a writer left
    /// behind. `surveyed_at` is asked of no pair — the exemption lives here, and
    /// nowhere else.
    def askedOf(fresh: Map[String, Json], kept: Map[String, Json]): List[String] =
        let claimed = compared();
        let other =
            List.filter(
                key -> key != "surveyed_at" and not List.memberOf(key, claimed),
                Set.toList(Set.union(Map.keysOf(fresh), Map.keysOf(kept)))
            );
        claimed ++ other

    /// The point two lines' coordinates part at, or -1 where they do not: one line
    /// shorter than the other differs where it stops.
    pub def firstDiff(fresh: List[Json], kept: List[Json]): Int32 =
        parted(fresh, kept, 0)

    def parted(fresh: List[Json], kept: List[Json], at: Int32): Int32 =
        match (fresh, kept) {
            case (Nil, Nil) => -1
            case (one :: more, only :: rest) =>
                if (same(one, only)) parted(more, rest, at + 1) else at
            case _ => at
        }

    /// What a feature's `geometry` member holds, JSON-null where it holds nothing.
    def geometryOf(feature: Feature): Json =
        Option.getWithDefault(Json.JNull, Map.get("geometry", feature))

    /// A feature's coordinates as the file gives them, one JSON pair per place.
    def coordinatesOf(feature: Feature): List[Json] =
        match geometryOf(feature) {
            case Json.JObject(members) =>
                match Map.get("coordinates", members) {
                    case Some(Json.JArray(items)) => Vector.toList(items)
                    case _                        => Nil
                }
            case _ => Nil
        }

    /// Two JSON values answering for the same thing. Numbers are compared by value
    /// and not by spelling: a metre one writer spelled `5515` and another spelled
    /// `5515.0` is the metre the fence measures twice.
    pub def same(fresh: Json, kept: Json): Bool =
        match (fresh, kept) {
            case (Json.JNumber(one), Json.JNumber(only)) => BigDecimal.numericEquals(one, only)
            case (Json.JArray(one), Json.JArray(only))   => sameAll(Vector.toList(one), Vector.toList(only))
            case (Json.JObject(one), Json.JObject(only)) => sameMap(one, only)
            case (one, only)                             => one == only
        }

    def sameAll(fresh: List[Json], kept: List[Json]): Bool =
        match (fresh, kept) {
            case (Nil, Nil) => true
            case (one :: more, only :: rest) => same(one, only) and sameAll(more, rest)
            case _ => false
        }

    def sameMap(fresh: Map[String, Json], kept: Map[String, Json]): Bool =
        let mine = Set.toList(Map.keysOf(fresh));
        let theirs = Set.toList(Map.keysOf(kept));
        List.foldLeft((holds, key) -> holds and sameOption(Map.get(key, fresh), Map.get(key, kept)), true, mine) and
        List.foldLeft((holds, key) -> holds and Map.memberOf(key, fresh), true, theirs)

    def sameOption(fresh: Option[Json], kept: Option[Json]): Bool =
        match (fresh, kept) {
            case (Some(one), Some(only)) => same(one, only)
            case (None, None)            => true
            case _                       => false
        }

    /// A property as a drift line quotes it: JSON's own compact spelling, and
    /// `absent` where one side claims something the other does not.
    pub def shown(spelled: Option[Json]): String =
        match spelled {
            case None       => "absent"
            case Some(json) => Util.Json.toCompactString(json)
        }
}
