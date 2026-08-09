use Sys.Env
use Sys.Console
use Sys.Exit
use Util.Files
use Cli.Args
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
                    Stages.runAll(parsed#root)
            }
    };
    Exit.exit(code)

/// Checked once here rather than once per round, so a mistyped root reads as one
/// mistake instead of as every race being missing.
def checkRoot(root: String): Result[CliError, Unit] \ IO =
    forM(
        exists <- Files.exists(root) |> Result.mapErr(CliError.File);
        _      <- if (exists) Ok(()) else Err(CliError.InputPathNotFound(root));
        isDir  <- Files.isDirectory(root) |> Result.mapErr(CliError.File);
        _      <- if (isDir) Ok(()) else Err(CliError.RootNotADirectory(root))
    ) yield ()
