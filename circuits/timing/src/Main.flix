// The timing-lines report, which is the whole of this project: two seasons'
// feeds, the circuit's own published figures, and a printed verdict.
//
// `Report` reads the arguments; `Cli.TimingLines` reads the feeds and prints.
// Which sources here are symlinks into `flix/src`, and why the links are one per
// file, is `circuits/README.md`'s.
use Sys.Console
use Sys.Env
use Sys.Exit

def main(): Unit \ { Env, IO, Exit, Console } =
    Exit.exit(Report.exitCode(Env.getArgs()))
