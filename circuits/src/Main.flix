// The circuit geometry pipeline, under one jar:
//
//     nix run .#geometry -- survey    <circuit> [--answer <overpass.json>] [--fetch] [--write]
//     nix run .#geometry -- atlas     <circuit> [--file <atlas.geojson>]
//     nix run .#geometry -- diff      <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]
//     nix run .#geometry -- regenerate [<circuit> ...] [--write | --freeze]
//     nix run .#geometry -- probe     <lat>,<lon> [...] [--radius <km>]
//     nix run .#geometry -- timing-lines --csv <dir> <season>/<id> [--against <season>] [--tolerance <metres>]
//
// Each subcommand is a module that reads files, asks OpenStreetMap or writes one, and
// says what it found; this is the asking of a word once `Cli/Words.flix` has said which
// word it was, and the exit code one comes to. `survey` turns an answer into the file the
// app serves and lays it down only with `--write`; `--fetch` is the network raised as
// a flag rather than a word — it asks OpenStreetMap now, keeps the answer beside the
// circuit once the survey can read it, and travels on through the survey over what
// came back. The atlas reading stands beside the pipeline rather than in it: it
// measures a foreign line against a kept geometry and keeps its own file, never a
// served one. The probe asks before any of this: which relation a circuit is, asked
// of OpenStreetMap straight and printed for a human to author a config from. The
// timing-lines report reads two rounds' feeds through `flix/src`'s own CSV
// decoding, which nine symlinks bring into this project for it.
use Sys.Console
use Sys.Env
use Sys.Exit
use Time.Clock

def main(): Unit \ { Env, IO, Clock, Exit, Console } =
    match Env.getArgs() {
        case Nil =>
            Console.println(Cli.Words.usages());
            Exit.exit(0)
        case "--help" :: _ =>
            Console.println(Cli.Words.usages());
            Exit.exit(0)
        case typed :: rest =>
            match Cli.Words.find(typed) {
                case Some(one) =>
                    Exit.exit(Cli.Words.asking(one, rest))
                case None =>
                    Console.eprintln("\"${typed}\" is no command of these");
                    Console.eprintln(Cli.Words.usages());
                    Exit.exit(1)
            }
    }
