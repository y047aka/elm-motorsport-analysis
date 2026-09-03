mod Cli.Load.Unlisted {

    use Cli.FileTask

    /// The CSV files under the root that no round on the calendar names.
    ///
    /// Kept apart from the walk that finds them because this is the half that
    /// can be wrong unnoticed: the run still writes exactly what it should, and
    /// only the warnings are junk.
    pub def detect(tasks: List[FileTask.FileTask], found: List[String]): List[String] =
        let listed = tasks |> List.map(task -> roundKey(task#inputPath));
        found |> List.filter(path -> not List.memberOf(roundKey(path), listed))

    /// A CSV's round identity: the directory it sits in and the file it is.
    ///
    /// The two sides being compared are spelled by different means -- one built
    /// from a calendar entry, the other returned by a glob -- so everything
    /// above these two segments is dropped rather than trusted to match. That is
    /// what survives a trailing slash on the root, a `./` in the middle, and an
    /// absolute path meeting a relative one.
    def roundKey(path: String): (String, String) =
        match String.split({regex = "/"}, path) |> List.filter(seg -> seg != "" and seg != ".") |> List.reverse {
            case name :: dir :: _ => (dir, name)
            case name :: Nil      => ("", name)
            case Nil              => ("", "")
        }

}
