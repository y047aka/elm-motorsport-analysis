/// The words this jar answers. The dispatch looks a typed word up in the list below,
/// the help a run prints is that list's usages joined, and a word the list holds no
/// answer to is said to be no command of these. All three read the one list: a
/// dispatch, a help line and an unknown-word sentence that each name the words
/// themselves are three chances to disagree about which words the jar has.
///
/// A word is a case of an enum rather than a record holding the command's own
/// functions, for the two things a record cannot do. Its effect would have to be the
/// widest of the six, so `diff` — which reads two files and reaches no clock — would
/// declare a clock it never reads for the shape of a table. And a record pairs a word,
/// its run and its usage by hand, in a line nothing checks; `usage` and `asking` below
/// are matches over the cases, so a word that joins the jar has to be answered in both
/// before the jar compiles at all.
///
/// The list carries no reading of a word's arguments. Each command reads its own into
/// its own type — a `Diff.Args` is no `Report.Request` — and one record holding both
/// would trade the one thing each command is tested with, its `Cli.Args.Parsed` handed
/// back as a value, for a cast. So a word's arguments are tested where they are typed,
/// and what is held here is that every word has a run, a usage, and a usage that names
/// the word it belongs to.
pub mod Cli.Words {

    use Sys.Console
    use Time.Clock

    /// The words of the jar. A command module joins by being named here, and by being
    /// answered below — by its own word, its usage, its run and the list.
    pub enum Word with Eq {
        case Atlas
        case Diff
        case Probe
        case Regenerate
        case Survey
        case TimingLines
    }

    /// What a reader types to reach a word.
    pub def name(word: Word): String =
        match word {
            case Word.Atlas       => "atlas"
            case Word.Diff        => "diff"
            case Word.Probe       => "probe"
            case Word.Regenerate  => "regenerate"
            case Word.Survey      => "survey"
            case Word.TimingLines => "timing-lines"
        }

    /// The word's own help line: the flake app a reader types, beside the arguments
    /// that word takes. This is what a wrong argument to that word is refused with.
    pub def usage(word: Word): String =
        match word {
            case Word.Atlas       => Atlas.usage()
            case Word.Diff        => Diff.usage()
            case Word.Probe       => Probe.usage()
            case Word.Regenerate  => Regenerate.usage()
            case Word.Survey      => Survey.usage()
            case Word.TimingLines => Report.usage()
        }

    /// The run a word comes to, given the arguments that followed the word. The clock
    /// is the widest of what any word needs — the words that pace a request read it,
    /// and the words that read files do not — so it is the asking that carries it,
    /// rather than six signatures claiming it.
    pub def asking(word: Word, args: List[String]): Int32 \ { IO, Clock, Console } =
        match word {
            case Word.Atlas       => Atlas.exitCode(args)
            case Word.Diff        => Diff.exitCode(args)
            case Word.Probe       => Probe.exitCode(args)
            case Word.Regenerate  => Regenerate.exitCode(args)
            case Word.Survey      => Survey.exitCode(args)
            case Word.TimingLines => Report.exitCode(args)
        }

    /// The words, in the order the help prints them: the list the dispatch looks a
    /// typed word up in, and the "these" an unknown word is told it is no part of.
    pub def words(): List[Word] =
        Word.Atlas :: Word.Diff :: Word.Probe :: Word.Regenerate :: Word.Survey :: Word.TimingLines :: Nil

    /// The word a reader typed, where the jar answers to it.
    pub def find(typed: String): Option[Word] =
        List.find(one -> name(one) == typed, words())

    /// Every word's own usage, joined as the help prints them.
    pub def usages(): String =
        String.intercalate("\n", List.map(one -> usage(one), words()))
}
