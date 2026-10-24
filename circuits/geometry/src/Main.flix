// The circuit geometry tools, under one jar:
//
//     nix run .#geometry-diff   -- <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]
//     nix run .#geometry-survey -- <circuit> [--answer <overpass.json>] [--write]
//
// Each subcommand is a module that reads files and says what it found; this is the asking
// of a word and the exit code it comes to. The commands are named by what they do to the
// repository's own bytes — `diff` lays two kept geometries against each other, `survey`
// draws one out of a kept Overpass answer — so the flake's `geometry-<command>` names stay
// the ones the README, the specs and the agent instructions already use, with this jar
// behind them. What a command does not answer for is said by the one that does: a circuit
// nobody has surveyed yet sends the reader to the command that asks OpenStreetMap.
use Sys.Console
use Sys.Env
use Sys.Exit

/// The commands there are. A word outside this list is a mistake, and says so with the
/// usage: the reader is at a terminal and not reading a manual.
def commands(): List[String] =
    "diff" :: "survey" :: Nil

def main(): Unit \ { Env, IO, Exit, Console } =
    match Env.getArgs() {
        case Nil =>
            Console.println(usage());
            Exit.exit(0)
        case "diff" :: rest =>
            Exit.exit(Diff.exitCode(rest))
        case "survey" :: rest =>
            Exit.exit(Write.exitCode(rest))
        case word :: _ =>
            Console.eprintln("\"${word}\" is no command of these");
            Console.eprintln(usage());
            Exit.exit(1)
    }

/// Each command's own usage, which is the flake app a reader types beside the arguments it
/// takes. The list is the commands, so a third one adds its own sentence here and nowhere
/// else.
def usage(): String =
    Diff.usage() + "\n${Write.usage()}"
