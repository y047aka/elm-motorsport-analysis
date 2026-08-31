use Sys.Env
use Sys.Console
use Sys.Exit
use Util.Files
use Cli.Args
use Cli.Args.ParsedArgs
use Cli.Db
use Cli.Db.Jdbc
use Cli.Errors.CliError
use Cli.Stages

def main(): Unit \ {Env, IO, Exit, Console} =
    let code = match Args.parse(Env.getArgs()) {
        case Err(e) =>
            Console.eprintln("Error: ${e}");
            Console.eprintln(Args.usage());
            1
        case Ok(parsed) =>
            match checkRoot(parsed#root) {
                case Err(e) =>
                    Console.eprintln("Error: ${e}");
                    1
                case Ok(()) =>
                    runStages(parsed)
            }
    };
    Exit.exit(code)

/// Which handler the run's database writes meet. Without `--postgres` they meet
/// the one that drops them, and the run is the file-writing run it has always
/// been.
def runStages(parsed: ParsedArgs): Int32 \ {IO, Console} =
    match parsed#postgres {
        case None =>
            Db.runDiscarding(() -> Stages.runAll(parsed#root))
        case Some(url) =>
            match Jdbc.connect(url) {
                case Err(e) =>
                    Console.eprintln("Error: ${e}");
                    1
                case Ok(conn) =>
                    let code = Jdbc.runWith(conn, () -> Stages.runAll(parsed#root));
                    Jdbc.close(conn);
                    code
            }
    }

/// Checked once here rather than once per round, so a mistyped root reads as one
/// mistake instead of as every race being missing.
def checkRoot(root: String): Result[CliError, Unit] \ IO =
    forM(
        exists <- Files.exists(root) |> Result.mapErr(CliError.File);
        _      <- if (exists) Ok(()) else Err(CliError.InputPathNotFound(root));
        isDir  <- Files.isDirectory(root) |> Result.mapErr(CliError.File);
        _      <- if (isDir) Ok(()) else Err(CliError.RootNotADirectory(root))
    ) yield ()
