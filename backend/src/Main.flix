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
use Motorsport.CalendarFile

    use Motorsport.Calendar.Calendar
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
            onCalendar(calendar -> runServer(serve#port, serve#database, calendar))
        case Ok(Command.Convert(convert)) =>
            onCalendar(calendar ->
                match unknownRound(calendar, convert#exported) {
                    case Some(name) => roundNotFound(name)
                    case None       => onDirectories(convert#csv :: convert#out :: Nil, convert#database, conn ->
                        loadAndExport(conn, convert#csv, convert#out, convert#exported, calendar))
                })
        case Ok(Command.Load(load)) =>
            onCalendar(calendar ->
                onDirectories(load#csv :: Nil, load#database, conn -> Load.runAll(conn, load#csv, calendar)))
        case Ok(Command.Export(export)) =>
            onCalendar(calendar ->
                match unknownRound(calendar, export#exported) {
                    case Some(name) => roundNotFound(name)
                    case None       => onDirectories(export#out :: Nil, export#database, _ ->
                        Export.runAll(calendar, export#out, export#exported))
                })
    };
    Exit.exit(code)

/// The calendar is read once, before any stage: it is the worklist, the
/// calendar route, and the words in every file name, and a run that cannot
/// read it says so before touching a database.
def onCalendar(k: Calendar -> Int32 \ ef): Int32 \ ef + Env + IO + Console =
    match CalendarFile.read(calendarPath()) {
        case Err(e)     =>
            Console.eprintln("Error: ${e}");
            1
        case Ok(calendar) => k(calendar)
    }

/// `CALENDAR_FILE` says the same to every run in a shell as `DATABASE_URL`
/// does; the default sits beside the CSV directory the flake names.
def calendarPath(): String \ Env =
    match Env.getVar("CALENDAR_FILE") {
        case Some(path) => path
        case None       => CalendarFile.defaultPath()
    }

/// `--export-only` narrows the writing stage, and a name no round on the
/// calendar answers to fails the run before anything is written.
def unknownRound(calendar: Calendar, rounds: Cli.FileTask.Rounds): Option[String] =
    match rounds {
        case Cli.FileTask.Rounds.Every       => None
        case Cli.FileTask.Rounds.Only(names) =>
            names
                |> List.filterMap(name ->
                    match name {
                        case (season, id) =>
                            match Motorsport.Calendar.find(calendar, season, id) {
                                case None    => Some("${season}/${id}")
                                case Some(_) => None
                            }
                    })
                |> List.head
    }

def roundNotFound(name: String): Int32 \ Console =
    Console.eprintln("Error: --export-only names no round on the calendar: ${name}");
    1

/// A round that failed to load has no rows, so the export fails it too and
/// leaves the files it would have replaced alone. The rounds beside it are
/// written either way.
def loadAndExport(conn: Connection, csv: String, out: String, rounds: Cli.FileTask.Rounds, calendar: Calendar): Int32 \ {IO, Console, SqlRead, RawSql} =
    let loaded = Load.runAll(conn, csv, calendar);
    let exported = Export.runAll(calendar, out, rounds);
    if (loaded == 0 and exported == 0) 0 else 1

/// Both stages compute in a database, so one given none is one that cannot say
/// what it found.
def onDirectories(dirs: List[String], database: Option[String], stage: Connection -> Int32 \ ef): Int32 \ (ef - {Sqlitefx.Db, SqlSavepoint, RawSql}) + Env + IO + Console =
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
def runServer(port: Int32, database: Option[String], calendar: Calendar): Int32 \ {Env, IO, Console} =
    withDatabase(database, url -> {
        Console.println("Serving /api on port ${port}");
        match Server.serve(port, url, calendar) {
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

