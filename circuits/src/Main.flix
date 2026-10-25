// The circuit geometry pipeline, under one jar:
//
//     nix run .#geometry-fetch    -- <circuit> [--out <overpass.json>]
//     nix run .#geometry-survey   -- <circuit> [--answer <overpass.json>] [--write]
//     nix run .#geometry-write    -- <circuit> [--answer <overpass.json>] [--write]
//     nix run .#geometry-atlas    -- <circuit> [--file <atlas.geojson>]
//     nix run .#geometry-diff     -- <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]
//     nix run .#geometry-regenerate [<circuit> ...] [--write | --freeze]
//
// Each subcommand is a module that reads files, asks OpenStreetMap or writes one, and
// says what it found; this is the asking of a word, the usage a wrong word is answered
// with, and the exit code one comes to. The stages run one after another as the CLI's
// load and export do: `fetch` keeps an answer, `survey` turns a kept answer into the
// file the app serves, and `write` runs both off one reading of the arguments. The
// atlas reading stands beside the pipeline rather than in it: it measures a foreign
// line against a kept geometry and keeps its own file, never a served one.
use Sys.Console
use Sys.Env
use Sys.Exit
use Time.Clock

/// A word outside this list is a mistake, and is answered with the usage.
def commands(): List[String] =
    "atlas" :: "diff" :: "fetch" :: "regenerate" :: "survey" :: "write" :: Nil

def main(): Unit \ { Env, IO, Clock, Exit, Console } =
    match Env.getArgs() {
        case Nil =>
            Console.println(usage());
            Exit.exit(0)
        case "atlas" :: rest =>
            Exit.exit(Atlas.exitCode(rest))
        case "diff" :: rest =>
            Exit.exit(Diff.exitCode(rest))
        case "fetch" :: rest =>
            Exit.exit(Fetch.exitCode(rest))
        case "regenerate" :: rest =>
            Exit.exit(Regenerate.exitCode(rest))
        case "survey" :: rest =>
            Exit.exit(Write.exitCode(rest))
        case "write" :: rest =>
            Exit.exit(Write.writeExitCode(rest))
        case word :: _ =>
            Console.eprintln("\"${word}\" is no command of these");
            Console.eprintln(usage());
            Exit.exit(1)
    }

/// Each command's own usage: the flake app a reader types, beside the arguments it takes.
def usage(): String =
    Atlas.usage() + "\n${Diff.usage()}" + "\n${Fetch.usage()}" + "\n${Regenerate.usage()}" + "\n${Write.usage()}" + "\n${Write.writeUsage()}"
