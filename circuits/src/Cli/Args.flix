/// The asking of arguments every word of this CLI is written over, as the CLI
/// project's `Cli.Args` is: `Util.GetOpt` walks the tokens, each command declares
/// its own flags in its own `Setting` enum, and a command's `usage()` prints the
/// very descriptors it parsed with — so the flags a run accepts, the help that
/// lists them and the refusal of a wrong one cannot come apart.
///
/// What GetOpt cannot say is said by the command whose flags they are: whether a
/// named word answers to a circuit (`Circuit.byWord`) or to a round on the
/// calendar (`Motorsport.Calendar`), and whether two flags raised together answer
/// for one run at all (`--write` against `--freeze`).
pub mod Cli.Args {

    use Sys.Console
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    /// The arguments as given, when they are not what the command asks with.
    /// Each case already carries the sentence naming what was wrong; the derived
    /// one would wrap it in constructor syntax before it reaches stderr.
    pub enum ArgsError {
        case ParseErrors(List[String])
        case UnexpectedArguments(List[String])
    }

    instance ToString[ArgsError] {
        pub def toString(e: ArgsError): String = match e {
            // GetOpt's own sentences arrive with a newline of their own; the
            // reporting that prints them adds the next one.
            case ArgsError.ParseErrors(messages)       => List.join(" ", List.map(String.trimRight, messages))
            case ArgsError.UnexpectedArguments(extras) => "${List.join(", ", extras)} are not arguments this command reads."
        }
    }

    /// The walk every command shares: flags and words freely interspersed, and
    /// every complaint GetOpt collected rather than only the first.
    pub def scan(descrs: List[OptionDescr[s]], args: List[String]): Result[ArgsError, {options = List[s], words = List[String]}] =
        match Util.GetOpt.getOpt(Util.GetOpt.ArgOrder.Permute, descrs, args) {
            case Validation.Failure(errors) => Err(ArgsError.ParseErrors(Nec.toList(errors)))
            case Validation.Success(result) => Ok({options = result#options, words = result#nonOptions})
        }

    /// The answer a wrong argument comes to, as `flix/src`'s `main` answers it: the
    /// sentence naming what was wrong, the command's own usage under it, and exit
    /// code 1. A command reaches a wrong argument through this and nothing else.
    pub def refuseArgs(problem: String, usage: String): Int32 \ Console = {
        Console.eprintln("Error: ${problem}");
        Console.eprintln(usage);
        1
    }

    /// A flag is no file: `--out --write` is a reader who meant something else, and
    /// a run that read it as a path would keep an answer under a name no file can
    /// be called. GetOpt hands an argument over as it came; commands refuse one
    /// that stands as another flag with this, in the sentence naming the flag that
    /// wanted the file.
    pub def isFlag(word: String): Bool =
        String.startsWith({prefix = "--"}, word)

    /// The last named value wins, as a repeated option usually does — the reading
    /// `flix/src`'s `--database` set, which the probe's `--radius` and the report's
    /// `--against` and `--tolerance` follow.
    pub def lastNamed(asking: s -> Option[String], settings: List[s]): Option[String] =
        List.foldLeft(
            (held, setting) -> match asking(setting) {
                case None  => held
                case named => named
            },
            None,
            settings
        )
}
