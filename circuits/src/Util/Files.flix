/// Reading a file, writing one, and asking whether a path holds one: the commands these
/// serve are run by hand, so a geometry is read to be laid against another and an overlay
/// written to be looked at later. The globbing and the CSV-walking the load and the export
/// do are `flix/src`'s `Util.Files`. Two projects hold a module of this name — `flix/src`'s
/// and this one — and neither can reach the other's; the report reads through
/// `TimingLines.Files`, which resolves nothing.
pub mod Util.Files {

    use Sys.Env

    /// A file as one text, or what the filesystem said about it.
    pub def read(path: String): Result[String, String] \ IO =
        Fs.FileRead.runWithIO(
            () ->
                Fs.ReadFile.runWithFileRead(() -> Fs.ReadFile.read(placed(path)))
        )
            |> Result.mapErr(e -> "${e}")

    /// `text` written at `path`, which is created or replaced. The directories
    /// above it are made first, because the kept files of a circuit not surveyed
    /// before land in a directory that does not exist yet.
    pub def write(path: String, text: String): Result[String, Unit] \ IO = {
        let at = placed(path);
        Fs.FileWrite.runWithIO(
            () ->
                Fs.MkDirs.runWithFileWrite(
                    () ->
                        Fs.MkDirs.mkDirs(parentOf(at))
                )
        )
            |> Result.flatMap(
                _ ->
                    Fs.FileWrite.runWithIO(
                        () ->
                            Fs.WriteFile.runWithFileWrite(() -> Fs.WriteFile.write({str = text}, at))
                    )
            )
            |> Result.mapErr(e -> "${e}")
    }

    /// The names inside a directory — the kept evidence of a circuit no config
    /// answers to is found by looking, and the fence that looks asks the same
    /// directory the reader reads and writes ask.
    pub def list(dir: String): Result[String, List[String]] \ IO =
        Fs.DirList.runWithIO(
            () -> Fs.DirList.list(placed(dir))
        )
            |> Result.mapErr(e -> "${e}")

    /// Whether there is a file at `path` to read. This is the question a run asks before
    /// it decides that there is none, and `read` cannot answer it: its failure says only
    /// that nothing came, which an unreadable file says too, and the decision on the other
    /// side of the answer is that a circuit was never surveyed.
    pub def exists(path: String): Result[String, Bool] \ IO =
        let at = placed(path);
        Fs.FileStat.runWithIO(() -> Fs.FileStat.exists(at))
            |> Result.mapErr(e -> unstated(path, "is there anything", "${e}"))

    /// Whether `dir` is a directory whose names can be listed — which a run walking one
    /// asks before it lists it, since a plain file among the names it is walking is not a
    /// directory that keeps nothing.
    pub def isDirectory(dir: String): Result[String, Bool] \ IO =
        let at = placed(dir);
        Fs.FileStat.runWithIO(() -> Fs.FileStat.isDirectory(at))
            |> Result.mapErr(e -> unstated(dir, "is a directory", "${e}"))

    /// The sentence a stat that answered nothing is printed in: a failure, and not the
    /// `false` that would answer that there is nothing there, which is the answer a walk
    /// stops on quietly.
    def unstated(path: String, asked: String, cause: String): String =
        "cannot tell whether ${path} ${asked} (caused by: ${cause})"

    /// A path where the command was run from rather than where `flix` was started.
    /// The runner has to be in this project's own directory to find `flix.toml`, and a
    /// reader names `app/static/geometry/le_mans.geojson` from outside it.
    /// `GEOMETRY_FROM` is that outside directory, and the runner is the only thing
    /// that sets it: a run made inside the project names nothing, and falls back to
    /// the directory it is standing in, which is the same place.
    def placed(path: String): String \ IO =
        if (String.startsWith({prefix = "/"}, path)) path else "${runFrom()}/${path}"

    /// The directory a run of these commands was asked from.
    def runFrom(): String \ IO =
        Env.runWithIO(
            () ->
                match Env.getVar("GEOMETRY_FROM") {
                    case None        => Option.getWithDefault(".", Env.getCurrentWorkingDirectory())
                    case Some(named) => named
                }
        )

    /// The directory a path stands in, `.` when it names no directory — which is
    /// what a file written in the working directory is, and `mkDirs` of `.` is the
    /// statement that there is nothing to make.
    def parentOf(path: String): String =
        match List.init(String.splitOn({substr = "/"}, path)) {
            case None       => "."
            case Some(dirs) => String.intercalate("/", dirs)
        }
}
