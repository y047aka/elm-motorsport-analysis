use Sys.Env
use Sys.Console
use Sys.Exit
use Util.Files
use Cli.Args
use Cli.Args.Command
    use Sqlitefx.Jdbc
    import java.sql.Connection
use Cli.Errors.CliError
use Cli.Errors.checkDirectory
use Cli.Load
use Cli.Export

    use Sqlitefx.DbError
    use Sqlitefx.SqlRead
    use Sqlitefx.SqlWrite
    use Sqlitefx.SqlSavepoint
    use Sqlitefx.RawSql
def main(): Unit \ {Env, IO, Exit, Console} =
    let code = match Args.parse(Env.getArgs()) {
        case Err(e) =>
            Console.eprintln("Error: ${e}");
            Console.eprintln(Args.usage());
            1
        case Ok(Command.Serve(serve)) =>
            runServer(serve#port, serve#database)
        case Ok(Command.Convert(convert)) =>
            onDirectories(convert#csv :: convert#out :: Nil, convert#database, conn ->
                loadAndExport(conn, convert#csv, convert#out, convert#exported))
        case Ok(Command.Load(load)) =>
            onDirectories(load#csv :: Nil, load#database, conn -> Load.runAll(conn, load#csv))
        case Ok(Command.Export(export)) =>
            onDirectories(export#out :: Nil, export#database, _ -> Export.runAll(export#out, export#exported))
    };
    Exit.exit(code)

/// A round that failed to load has no rows, so the export fails it too and
/// leaves the files it would have replaced alone. The rounds beside it are
/// written either way.
def loadAndExport(conn: Connection, csv: String, out: String, rounds: Cli.FileTask.Rounds): Int32 \ {IO, Console, SqlRead, RawSql} =
    let loaded = Load.runAll(conn, csv);
    let exported = Export.runAll(out, rounds);
    if (loaded == 0 and exported == 0) 0 else 1

/// Both stages compute in a database, so one given none is one that cannot say
/// what it found.
def onDirectories(dirs: List[String], database: Option[String], stage: Connection -> Int32 \ ef): Int32 \ (ef - {Db.DbAll}) + Env + IO + Console =
    match Result.traverseX(checkDirectory, dirs) {
        case Err(e) =>
            Console.eprintln("Error: ${e}");
            1
        case Ok(()) =>
            withDatabase(database, url ->
                match DbError.runWithFailure(() -> RawSql.runWithAllow(() -> Jdbc.withConnection(Db.connection(url), stage))) {
                    case Ok(code) => code
                    case Err(e)   =>
                        Console.eprintln("Error: ${DbError.describeFailure(e)}");
                        1
                }
            )
    }

/// The database is reached once per request, so the server starts before one is
/// up and reports it per request.
def runServer(port: Int32, database: Option[String]): Int32 \ {Env, IO, Console} =
    withDatabase(database, url -> {
        Console.println("Serving /api on port ${port}");
        match Server.serve(port, url) {
            case Ok(())  => 0
            case Err(e)  => Console.eprintln("Error: ${e}"); 1
        }
    })

def withDatabase(database: Option[String], f: String -> Int32 \ ef): Int32 \ ef + Env + Console =
    match databaseUrl(database) {
        case None =>
            Console.eprintln("Error: no database. Pass --database <jdbc url> or set DATABASE_URL.");
            1
        case Some(url) => f(url)
    }

/// `--database` first, then `DATABASE_URL`: the flag points one run somewhere
/// else, and the variable is how a shell that already has a database hands the
/// same one to every run made in it.
def databaseUrl(database: Option[String]): Option[String] \ Env =
    match database {
        case Some(url) => Some(url)
        case None      => Env.getVar("DATABASE_URL")
    }

