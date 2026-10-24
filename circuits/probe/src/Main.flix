// The probe, which is the whole of this project: a box on the earth, the
// relations OpenStreetMap holds in it, and each one's ways measured.
//
// `Probe` reads the arguments, asks and prints; `Overpass` is the asking and the
// shape of an answer, and `Candidates` is the reading of an answer already got.
// Nothing here opens a file, writes one, or names a database: a probe is what a
// reader does before there is a circuit to draw.
use Sys.Console
use Time.Clock
use Sys.Env
use Sys.Exit

def main(): Unit \ { Clock, Console, Env, Exit, IO } =
    Exit.exit(Probe.exitCode(Env.getArgs()))
