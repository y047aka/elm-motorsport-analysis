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
///
/// A word is three steps over two values, and the two values are this module's:
/// `Parsed`, the arguments as far as the flag table reads them, and `Outcome`, what
/// the run came to. `comeTo` is the only thing in the project that turns either
/// into an exit code, so a command's own code holds no printing of a refusal, no
/// exit code and no answer to `--help` — only the readings, and the verdict one of
/// them answers.
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
    /// every complaint GetOpt collected rather than only the first. Each command
    /// names the step from these tokens to its own arguments `completed` and hands
    /// that one function to both its `parse` and to `answer` below, so a test can
    /// never read arguments the run does not.
    pub type alias Scanned[s] = {options = List[s], words = List[String]}

    pub def scan(descrs: List[OptionDescr[s]], args: List[String]): Result[ArgsError, Scanned[s]] =
        match Util.GetOpt.getOpt(Util.GetOpt.ArgOrder.Permute, descrs, args) {
            case Validation.Failure(errors) => Err(ArgsError.ParseErrors(Nec.toList(errors)))
            case Validation.Success(result) => Ok({options = result#options, words = result#nonOptions})
        }

    /// The one flag every command takes, declared once and named by the
    /// command's own `Help` case — so the flag table of each usage lists it
    /// whether or not the command reads anything else.
    pub def helpDescr(help: s): OptionDescr[s] =
        {
            optionIds     = Nil,
            optionNames   = "help" :: Nil,
            argDescriptor = ArgDescr.NoArg(help),
            explanation   = "print this usage and stop"
        }

    /// The arguments as far as the flag table reads them, which is as far as no
    /// command's own reading is asked: `--help` and a wrong argument are both
    /// answered out of the descriptors alone. `--help` is answered before
    /// `complete` runs, since a run that asked for help asked for no circuit and no
    /// `--csv` too; being a value rather than a printing, it is read by a test.
    pub enum Parsed[args] {
        case Help(String)
        case Refused({problem = ArgsError, usage = String})
        case Asked(args)
    }

    /// The walk, up to the point the command's own `complete` reads a word.
    pub def prepare(
        descrs: List[OptionDescr[s]],
        usage: String,
        isHelp: s -> Bool,
        complete: Scanned[s] -> Result[ArgsError, args],
        args: List[String]
    ): Parsed[args] =
        match scan(descrs, args) {
            case Err(problem) => Parsed.Refused({problem = problem, usage = usage})
            case Ok(scanned) =>
                if (List.exists(isHelp, scanned#options))
                    Parsed.Help(usage)
                else
                    match complete(scanned) {
                        case Err(problem) => Parsed.Refused({problem = problem, usage = usage})
                        case Ok(asked)    => Parsed.Asked(asked)
                    }
        }

    /// What a run came to, before anyone prints it or exits with it. The two nonzero
    /// cases mean opposite things, which is why they are two cases and not a code:
    /// `Verdict` is the negative answer the reader came for — the drawing moved, one
    /// line moved a season later — said on stdout, since a fence that could not say it
    /// failed would pass by construction; `Failed` is a run that never got to answer,
    /// said on stderr under the same `Error: ` a wrong argument is.
    ///
    /// Each case holds the lines left to print, in order. A run that printed its report
    /// while it walked it — the fence over several circuits, the atlas's table — leaves
    /// the list empty, the exit code being all that is left to say.
    pub enum Outcome {
        case Done(List[String])
        case Verdict(List[String])
        case Failed(String)
    }

    /// The exit code a word comes to: the usage for `--help`, the sentence and the
    /// usage for a wrong argument, and the run's outcome for arguments it can ask
    /// with. Every command's `exitCode` is this over its own `arguments` and `asking`;
    /// nothing else in the project makes an exit code.
    pub def comeTo(args: Parsed[args], asking: args -> Outcome \ ef): Int32 \ (ef + Console) =
        match args {
            case Parsed.Help(usage) =>
                Console.println(usage);
                0
            case Parsed.Refused({problem = problem, usage = usage}) => refuseArgs("${problem}", usage)
            case Parsed.Asked(asked) => verdictOf(asking(asked))
        }

    /// The exit code an outcome comes to, and the stream its lines go to.
    pub def verdictOf(outcome: Outcome): Int32 \ Console = match outcome {
        case Outcome.Done(said)    => say(said); 0
        case Outcome.Verdict(said) => say(said); 1
        case Outcome.Failed(why)   =>
            Console.eprintln("Error: ${why}");
            1
    }

    def say(said: List[String]): Unit \ Console =
        foreach (line <- said)
            Console.println(line)

    /// A run written as its readings: a reading that failed is a run that never got to
    /// a verdict, and a run that read everything is the verdict its readings came to.
    pub def outcomeOf(ran: Result[String, Outcome]): Outcome = match ran {
        case Err(problem) => Outcome.Failed(problem)
        case Ok(verdict)  => verdict
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
