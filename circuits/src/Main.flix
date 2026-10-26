// The circuit geometry pipeline, under one jar:
//
//     nix run .#geometry -- fetch     <circuit> [--out <overpass.json>]
//     nix run .#geometry -- survey    <circuit> [--answer <overpass.json>] [--write]
//     nix run .#geometry -- write     <circuit> [--answer <overpass.json>] [--write]
//     nix run .#geometry -- atlas     <circuit> [--file <atlas.geojson>]
//     nix run .#geometry -- diff      <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]
//     nix run .#geometry -- regenerate [<circuit> ...] [--write | --freeze]
//     nix run .#geometry -- probe     <lat>,<lon> [...] [--radius <km>]
//     nix run .#geometry -- timing-lines --csv <dir> <season>/<id> [--against <season>] [--tolerance <metres>]
//
// Each subcommand is a module that reads files, asks OpenStreetMap or writes one, and
// says what it found; this is the asking of a word, the usage a wrong word is answered
// with, and the exit code one comes to. The stages run one after another as the CLI's
// load and export do: `fetch` keeps an answer, `survey` turns a kept answer into the
// file the app serves, and `write` runs both off one reading of the arguments. The
// atlas reading stands beside the pipeline rather than in it: it measures a foreign
// line against a kept geometry and keeps its own file, never a served one. The
// probe asks before any of this: which relation a circuit is, asked of
// OpenStreetMap straight and printed for a human to author a config from. The
// timing-lines report reads two rounds' feeds through `flix/src`'s own CSV
// decoding, which nine symlinks bring into this project for it.
use Sys.Console
use Sys.Env
use Sys.Exit
use Time.Clock

/// A word outside this list is a mistake, and is answered with the usage.
def commands(): List[String] =
    "atlas" :: "diff" :: "fetch" :: "probe" :: "regenerate" :: "survey" :: "timing-lines" :: "write" :: Nil

def main(): Unit \ { Env, IO, Clock, Exit, Console } =
    match Env.getArgs() {
        case Nil =>
            Console.println(usage());
            Exit.exit(0)
        case "--help" :: _ =>
            Console.println(usage());
            Exit.exit(0)
        case "atlas" :: rest =>
            Exit.exit(Atlas.exitCode(rest))
        case "diff" :: rest =>
            Exit.exit(Diff.exitCode(rest))
        case "fetch" :: rest =>
            Exit.exit(Fetch.exitCode(rest))
        case "probe" :: rest =>
            Exit.exit(Probe.exitCode(rest))
        case "regenerate" :: rest =>
            Exit.exit(Regenerate.exitCode(rest))
        case "survey" :: rest =>
            Exit.exit(Write.exitCode(rest))
        case "timing-lines" :: rest =>
            Exit.exit(Report.exitCode(rest))
        case "write" :: rest =>
            Exit.exit(Write.writeExitCode(rest))
        case word :: _ =>
            Console.eprintln("\"${word}\" is no command of these");
            Console.eprintln(usage());
            Exit.exit(1)
    }

/// Each command's own usage: the flake app a reader types, beside the arguments it takes.
def usage(): String =
    Atlas.usage() + "\n${Diff.usage()}" + "\n${Fetch.usage()}" + "\n${Probe.usage()}" + "\n${Regenerate.usage()}" + "\n${Write.usage()}" + "\n${Write.writeUsage()}" + "\n${Report.usage()}"
