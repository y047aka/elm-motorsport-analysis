// The circuit geometry tools, under one jar:
//
//     nix run .#geometry-diff   -- <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]
//     nix run .#geometry-survey -- <circuit> [--answer <overpass.json>] [--write]
//
// Each subcommand is a module that reads files and says what it found; this is the asking of
// a word, the usage a wrong word is answered with, and the exit code a command comes to.
use Sys.Console
use Sys.Env
use Sys.Exit

/// A word outside this list is a mistake, and is answered with the usage.
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

/// Each command's own usage: the flake app a reader types, beside the arguments it takes.
def usage(): String =
    Diff.usage() + "\n${Write.usage()}"
