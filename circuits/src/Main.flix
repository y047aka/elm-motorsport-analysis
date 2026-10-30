// The circuit geometry pipeline, under one jar:
//
//     nix run .#geometry -- survey    <circuit> [--answer <overpass.json>] [--fetch] [--write]
//     nix run .#geometry -- atlas     <circuit> [--file <atlas.geojson>]
//     nix run .#geometry -- diff      <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]
//     nix run .#geometry -- regenerate [<circuit> ...] [--write | --freeze]
//     nix run .#geometry -- probe     <lat>,<lon> [...] [--radius <km>]
//     nix run .#geometry -- timing-lines --csv <dir> <season>/<id> [--against <season>] [--tolerance <metres>]
//
// Each word is a module — its readings, its asking if it asks one, and its
// printing; this is the dispatch of a word, the usage a wrong one is answered
// with, and the exit code one comes to. `backend/src`'s CSV decoding, brought in by
// eight symlinks, serves the timing-lines word alone.
use Sys.Console
use Sys.Env
use Sys.Exit
use Time.Clock

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
        case "probe" :: rest =>
            Exit.exit(Probe.exitCode(rest))
        case "regenerate" :: rest =>
            Exit.exit(Regenerate.exitCode(rest))
        case "survey" :: rest =>
            Exit.exit(Survey.exitCode(rest))
        case "timing-lines" :: rest =>
            Exit.exit(TimingLines.exitCode(rest))
        case word :: _ =>
            Console.eprintln("\"${word}\" is no command of these");
            Console.eprintln(usage());
            Exit.exit(1)
    }

/// Each command's own usage: the flake app a reader types, beside the arguments it takes.
def usage(): String =
    Atlas.usage() + "\n${Diff.usage()}" + "\n${Probe.usage()}" + "\n${Regenerate.usage()}" + "\n${Survey.usage()}" + "\n${TimingLines.usage()}"
