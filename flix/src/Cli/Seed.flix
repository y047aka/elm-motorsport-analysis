/// The rows a bundled database starts with. `COPY laps TO` wrote them, so a
/// line is `Cli.Db.Schema.columns` separated by tabs, with `\N` where a column
/// was null -- which is what `Cli.Db.Row` reads a fetched row as, down to the
/// `t`/`f` of a boolean and the `{1,NULL}` of an array.
///
/// The file therefore cannot hold a field with a tab or a backslash in it. The
/// archive has none, and the run that writes the file checks.
mod Cli.Seed {

    import java.io.FileInputStream
    import java.io.IOException
    import java.lang.{String => JString}
    import java.nio.charset.StandardCharsets
    import java.util.zip.GZIPInputStream

    use Cli.Db
    use Cli.Db.LapRow
    use Cli.Db.LapRow.LapRow
    use Cli.Db.Schema

    /// Rows per `INSERT` batch, which is what holds the whole file from being
    /// a list of records at once.
    def chunkSize(): Int32 = 5000

    /// Seeds a database that has none of these rows yet, and leaves one that
    /// has them alone: the file is what the round archive was when the build
    /// was made, and a database already holding it is not to be rebuilt on
    /// every launch.
    pub def loadIfEmpty(path: String): Result[String, Int32] \ {Db, IO} =
        forM(
            _     <- Db.execute(Schema.createTableIfMissing());
            rows  <- Db.fetch("SELECT COUNT(*) FROM laps");
            count <- read(rows);
            added <- if (count == 0) load(path) else Ok(0)
        ) yield added

    def read(rows: List[List[Option[String]]]): Result[String, Int32] =
        match rows {
            case row :: _ => Cli.Db.Row.int(0, row)
            case Nil      => Err("the row count came back with no row")
        }

    def load(path: String): Result[String, Int32] \ {Db, IO} =
        forM(
            text  <- decompress(path);
            added <- insertChunks(String.lines(text) |> List.filter(line -> line != ""), 0)
        ) yield added

    def insertChunks(lines: List[String], added: Int32): Result[String, Int32] \ Db =
        match lines {
            case Nil => Ok(added)
            case _   =>
                let (chunk, rest) = List.splitAt(chunkSize(), lines);
                match Result.traverse(toRow, chunk) {
                    case Err(cause) => Err(cause)
                    case Ok(rows)   => match Db.insertLaps(rows) {
                        case Err(cause) => Err(cause)
                        case Ok(sent)   => insertChunks(rest, added + sent)
                    }
                }
        }

    /// One line of the file, which is the format's whole surface.
    pub def toRow(line: String): Result[String, LapRow] =
        LapRow.fromRow(String.splitOn({substr = "\t"}, line) |> List.map(cell ->
            if (cell == "\\N") None else Some(cell)
        ))

    def decompress(path: String): Result[String, String] \ IO =
        try {
            let stream = new GZIPInputStream(new FileInputStream(path));
            let bytes = stream.readAllBytes();
            stream.close();
            Ok(new JString(bytes, StandardCharsets.UTF_8))
        } catch {
            case e: IOException => Err("could not read ${path} (caused by: ${e.getMessage()})")
        }

}
