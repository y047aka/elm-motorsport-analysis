use Sys.Env
use Sys.Console
use Sys.Exit
use Util.Files
use Cli.Args
use Cli.Args.Command
use Cli.Db.Jdbc
use Cli.Errors.CliError
use Cli.Server
use Cli.Stages

def main(): Unit \ {Env, IO, Exit, Console} =
    let code = match Args.parse(Env.getArgs()) {
        case Err(e) =>
            Console.eprintln("Error: ${e}");
            Console.eprintln(Args.usage());
            1
        case Ok(Command.Serve(serve)) =>
            runServer(serve#port, serve#postgres, serve#seed)
        case Ok(Command.Convert(convert)) =>
            match checkRoot(convert#root) {
                case Err(e) =>
                    Console.eprintln("Error: ${e}");
                    1
                case Ok(()) =>
                    runStages(convert#root, convert#postgres)
            }
    };
    Exit.exit(code)

/// The run computes in a database, so a run given none is one that cannot say
/// what it found.
def runStages(root: String, postgres: Option[String]): Int32 \ {Env, IO, Console} =
    withDatabase(postgres, url ->
        match Jdbc.connect(url) {
            case Err(e) =>
                Console.eprintln("Error: ${e}");
                1
            case Ok(conn) =>
                let code = Jdbc.runWith(conn, () -> Stages.runAll(root));
                Jdbc.close(conn);
                code
        }
    )

/// The database is reached once per request, so the server starts before one is
/// up and reports it per request. The seeding is the exception: it is what makes
/// a database worth reading, so it is done before the first request rather than
/// during one.
def runServer(port: Int32, postgres: Option[String], seed: Option[String]): Int32 \ {Env, IO, Console} =
    withDatabase(postgres, url ->
        match seedRows(url, seed) {
            case Err(e) => Console.eprintln("Error: ${e}"); 1
            case Ok(()) =>
                Console.println("Serving /api on port ${port}");
                match Server.serve(port, url) {
                    case Ok(())  => 0
                    case Err(e)  => Console.eprintln("Error: ${e}"); 1
                }
        }
    )

def seedRows(url: String, seed: Option[String]): Result[String, Unit] \ {IO, Console} =
    match seed {
        case None       => Ok(())
        case Some(path) =>
            forM(
                conn  <- Jdbc.connect(url);
                added <- {
                    let result = Jdbc.runWith(conn, () -> Cli.Seed.loadIfEmpty(path));
                    Jdbc.close(conn);
                    result
                }
            ) yield (if (added > 0) Console.println("Seeded ${added} laps from ${path}") else ())
    }

def withDatabase(postgres: Option[String], f: String -> Int32 \ ef): Int32 \ ef + Env + Console =
    match databaseUrl(postgres) {
        case None =>
            Console.eprintln("Error: no database. Pass --postgres <jdbc url> or set DATABASE_URL.");
            1
        case Some(url) => f(url)
    }

/// `--postgres` first, then `DATABASE_URL`: the flag points one run somewhere
/// else, and the variable is how a shell that already has a database hands the
/// same one to every run made in it.
def databaseUrl(postgres: Option[String]): Option[String] \ Env =
    match postgres {
        case Some(url) => Some(url)
        case None      => Env.getVar("DATABASE_URL")
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
