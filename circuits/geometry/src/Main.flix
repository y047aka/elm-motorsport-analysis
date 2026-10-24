// The circuit geometry tools, under one command:
//
//     nix run .#geometry -- diff <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]
//
// Each subcommand is a module that reads files and says what it found; this is the
// asking of a word and the exit code it comes to. The commands are named by what they
// do to the repository's own bytes — `diff` lays two kept geometries against each
// other, and the ones still to move here write one, re-lay them all, and measure a
// foreign line against a kept one — so the flake's `geometry-<command>` names stay the
// ones the README, the specs and the agent instructions already use, with this jar
// behind them.
use Sys.Console
use Sys.Env
use Sys.Exit

/// The commands there are. A word outside this list is a mistake, and says so with the
/// usage: the reader is at a terminal and not reading a manual.
def commands(): List[String] =
    "diff" :: Nil

def main(): Unit \ { Env, IO, Exit, Console } =
    match Env.getArgs() {
        case Nil =>
            Console.println(usage());
            Exit.exit(0)
        case "diff" :: rest =>
            Exit.exit(Diff.exitCode(rest))
        case word :: _ =>
            Console.eprintln("\"${word}\" is no command of these; the commands are ${String.intercalate(", ", commands())}");
            Console.eprintln(usage());
            Exit.exit(1)
    }

def usage(): String =
    "usage: nix run .#geometry -- <${String.intercalate("|", commands())}> ..."
