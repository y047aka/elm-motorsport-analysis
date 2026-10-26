/// The pipeline's asking that keeps an answer: the question a circuit's relation is
/// answered with, kept beside the config that will survey it.
///
///     nix run .#geometry -- fetch <circuit> [--out <overpass.json>]
///
/// The stages are the CLI's two, in the same shape: this is the asking that keeps
/// an answer beside a circuit, and `Write.flix` is the turning of an answer into
/// the file the app serves — whose whole run, `-- write`, does both off one
/// reading of the arguments as `cli-run` runs load and export.
///
/// `fetch` and `write` are the only commands that reach the network, and only
/// through `Overpass`; a run over a kept answer — the survey's, the fence's, the
/// diff's — asks nothing of anyone.
pub mod Fetch {

    use Circuit.Circuit
    use Cli.Args.ArgsError
    use Sys.Console
    use Time.Clock
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    // ----------------------------------------------------------------- the fetching

    /// One circuit, and where its answer lands — the circuit's own directory unless
    /// the reader named another file.
    pub type alias Args = {
        circuit = Circuit,
        out     = String
    }

    enum Setting with Eq {
        case Help
        case Out(String)
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
        Cli.Args.helpDescr(Setting.Help) ::
        {
            optionIds     = Nil,
            optionNames   = "out" :: Nil,
            argDescriptor = ArgDescr.ReqArg(path -> Some(Setting.Out(path)), "OVERPASS.JSON"),
            explanation   = "keep the answer here instead of beside the circuit's config"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    pub def parse(args: List[String]): Result[ArgsError, Args] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  =>
                complete(scanned#words, Cli.Args.lastNamed(outNamed, scanned#options))
        }

    /// A flag is no file: `--out --write` is a reader who meant something else, and
    /// a run that read it as a path would keep an answer under a name no file can
    /// be called. GetOpt hands the argument over as it came; it is the completing
    /// that refuses one.
    def complete(named: List[String], out: Option[String]): Result[ArgsError, Args] =
        match out {
            case Some(path) if Cli.Args.isFlag(path) =>
                Err(ArgsError.ParseErrors("--out names no file to write" :: Nil))
            case _ =>
                match named {
                    case Nil => Err(ArgsError.ParseErrors("fetch reads one circuit." :: Nil))
                    case one :: _ =>
                        match Circuit.byWord(one) {
                            case None => Err(ArgsError.ParseErrors(Circuit.unknown(one) :: Nil))
                            case Some(circuit) =>
                                Ok({
                                    circuit = circuit,
                                    out = Option.getWithDefault(Circuit.keptAnswer(circuit), out)
                                })
                        }
                }
        }

    def outNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.Out(path) => Some(path)
            case _                 => None
        }

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "usage: nix run .#geometry -- fetch <circuit> [--out <overpass.json>]",
            optionDescrs()
        )

    /// The exit code of the asking: 1 for a word no circuit answers to, a runner none
    /// of them reached, an answer the survey cannot read, and a file it could not
    /// write.
    pub def exitCode(args: List[String]): Int32 \ { IO, Clock, Console } =
        Cli.Args.answer(
            optionDescrs(),
            usage(),
            isHelp,
            args,
            scanned -> complete(scanned#words, Cli.Args.lastNamed(outNamed, scanned#options)),
            askOf
        )

    def askOf(asked: Args): Int32 \ { IO, Clock, Console } =
        match Overpass.askRelation(asked#circuit#relation) {
            case Err(problem) =>
                Console.eprintln("${asked#circuit#word}: ${problem}");
                1
            case Ok(text) => kept(asked, text)
        }

    /// An answer is kept only once the survey can read it: an answer that surveys
    /// nothing is evidence nobody can re-run. A runner's HTML page, a reply that
    /// stopped half way through its JSON, and an answer whose relation will not chain
    /// into a lap are all met here, in the same words the survey itself would say
    /// them in, rather than in a file kept to be discovered later.
    def kept(asked: Args, text: String): Int32 \ { IO, Console } =
        match surveyable(text, asked#circuit) {
            case Err(problem) =>
                Console.eprintln("${asked#out}: the answer surveys nothing: ${problem}");
                1
            case Ok(reading) =>
                match Util.Files.write(asked#out, text) {
                    case Err(problem) =>
                        Console.eprintln("${asked#out}: ${problem}");
                        1
                    case Ok(_) =>
                        let elements = Int32.toString(List.length(reading#elements));
                        let stamp = match reading#surveyedAt {
                            case None    => ""
                            case Some(at) => ", surveyed at ${at}"
                        };
                        Console.println("${asked#circuit#word}: kept an answer of ${elements} elements${stamp} at ${asked#out}");
                        0
                }
        }

    /// Whether this text is an answer the survey can read: the JSON, the circuit's
    /// relation, the chained lap and the line the circuit says that lap starts at —
    /// everything the kept file will be re-read for, asked before a byte is kept.
    pub def surveyable(text: String, circuit: Circuit): Result[String, Survey.Answer] =
        match Survey.answer(text) {
            case Err(problem) => Err(problem)
            case Ok(reading) =>
                match Survey.lapOf(reading, circuit) {
                    case Err(problem) => Err(problem)
                    case Ok(_)        => Ok(reading)
                }
        }
}
