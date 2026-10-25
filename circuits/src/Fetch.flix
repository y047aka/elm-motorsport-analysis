/// The asking stage of the pipeline: the commands that put a question to OpenStreetMap.
///
///     nix run .#geometry-fetch -- <circuit> [--out <overpass.json>]
///     nix run .#geometry-write -- <circuit> [--answer <overpass.json>] [--write]
///
/// The stages are the CLI's two, in the same shape: `fetch` is the asking that keeps
/// an answer beside a circuit, and `survey` is the turning of an answer into the file
/// the app serves. `write` runs both off one reading of the arguments — as `cli-run`
/// runs load and export — and takes the survey's flags unchanged, so one flag means
/// one thing at either command. What differs is only what happens when no answer is
/// named: the survey sends the reader to the kept answer, and this asks OpenStreetMap.
///
/// Only these two commands reach the network, and only through `Overpass`; a run over
/// a kept answer — the fence's, the diff's — asks nothing of anyone.
pub mod Fetch {

    use Circuit.Circuit
    use Sys.Console
    use Time.Clock

    // ----------------------------------------------------------------- the fetching

    /// One circuit, and where its answer lands — the circuit's own directory unless
    /// the reader named another file.
    pub type alias Args = {
        circuit = Circuit,
        out     = String
    }

    pub def parse(args: List[String]): Result[String, Args] =
        walked(Nil, args, None)

    def walked(named: List[String], rest: List[String], out: Option[String]): Result[String, Args] =
        match rest {
            case Nil => complete(named, out)
            case "--out" :: path :: further =>
                // A flag is no file: `--out --write` is a reader who meant something
                // else, and a run that read it as a path would keep an answer under a
                // name no file can be called.
                if (String.startsWith({prefix = "--"}, path)) Err("--out names no file to write")
                else walked(named, further, Some(path))
            case "--out" :: Nil => Err("--out names no file to write")
            case one :: further =>
                if (String.startsWith({prefix = "--"}, one)) Err("\"${one}\" is no flag of this command")
                else walked(one :: named, further, out)
        }

    def complete(named: List[String], out: Option[String]): Result[String, Args] =
        match named {
            case Nil => Err(usage())
            case one :: _ =>
                match Circuit.byWord(one) {
                    case None => Err(Circuit.unknown(one))
                    case Some(circuit) =>
                        Ok({
                            circuit = circuit,
                            out = Option.getWithDefault(Circuit.keptAnswer(circuit), out)
                        })
                }
        }

    pub def usage(): String =
        "usage: nix run .#geometry-fetch -- <circuit> [--out <overpass.json>]"

    /// The exit code of the asking: 1 for a word no circuit answers to, a runner none
    /// of them reached, an answer the survey cannot read, and a file it could not
    /// write.
    pub def exitCode(args: List[String]): Int32 \ { IO, Clock, Console } =
        match parse(args) {
            case Err(problem) =>
                Console.eprintln("${problem}");
                1
            case Ok(asked) => askOf(asked)
        }

    def askOf(asked: Args): Int32 \ { IO, Clock, Console } =
        match Overpass.paced(() -> Overpass.ask(Overpass.pipelineQuery(asked#circuit#relation))) {
            case Err(problem) =>
                Console.eprintln("${asked#circuit#word}: ${problem}");
                1
            case Ok(text) => kept(asked, text)
        }

    /// An answer is kept only once the survey can read it: an answer that surveys
    /// nothing is evidence nobody can re-run, and a runner's HTML page, a reply that
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
    /// The answer comes back whole for the report, which prints what it says about
    /// itself.
    pub def surveyable(text: String, circuit: Circuit): Result[String, Survey.Answer] =
        match Survey.answer(text) {
            case Err(problem) => Err(problem)
            case Ok(reading) =>
                match Survey.lapOf(reading, circuit) {
                    case Err(problem) => Err(problem)
                    case Ok(_)        => Ok(reading)
                }
        }

    // ---------------------------------------------------------------- the whole run

    /// The whole pipeline off one reading of the arguments: the answer named is read,
    /// and no answer named means asking OpenStreetMap now rather than a kept answer.
    /// The survey does the rest — the same `surveyed` the kept answer travels through,
    /// so a live survey and a fence over a kept one fail in the same words.
    ///
    /// A live asking keeps nothing by itself: `fetch` is the command that decides what
    /// a run keeps beside a circuit, and a run that only wants the geometry should not
    /// take the map's newest answer with it.
    pub def writeExitCode(args: List[String]): Int32 \ { IO, Clock, Console } =
        match Write.parse(args) {
            case Err(problem) =>
                Console.eprintln("${problem}");
                1
            case Ok(asked) =>
                if (asked#asked)
                    Write.ask(asked)
                else
                    live(asked)
        }

    /// The asking, then the survey over what came back. The answer's name in the
    /// report is the question rather than a file, because a file is what the reader
    /// did not name.
    def live(asked: Write.Args): Int32 \ { IO, Clock, Console } =
        match Overpass.paced(() -> Overpass.ask(Overpass.pipelineQuery(asked#circuit#relation))) {
            case Err(problem) =>
                Console.eprintln("${asked#circuit#word}: ${problem}");
                1
            case Ok(text) =>
                let fromRunner = {
                    circuit = asked#circuit,
                    answer = "OpenStreetMap relation ${asked#circuit#relation}",
                    asked = asked#asked,
                    write = asked#write
                };
                Write.surveyed(fromRunner, text)
        }
}
