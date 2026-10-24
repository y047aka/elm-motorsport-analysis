/// Reading a file, and writing one. The commands these readings serve are the
/// ones a person runs by hand, so both directions belong to them: a geometry is
/// read to be laid against another, and an overlay or a measured line is written
/// to be looked at later. The globbing, the stat-ing and the CSV-walking the load
/// and the export do are `flix/src`'s `Util.Files`, and the report that reads a
/// timing feed holds a third module of the same name with no way to write — at
/// `flix/src`, `circuits/timing`'s and here, three modules, three projects, one
/// name, none of them able to reach the others'.
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
