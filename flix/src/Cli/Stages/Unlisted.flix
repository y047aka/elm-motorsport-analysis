mod Cli.Stages.Unlisted {

    use Cli.FileTask

    /// The CSV files under the root that no round on the calendar names.
    ///
    /// Pure, and separate from the walk that finds them, because this is the
    /// half that can be wrong in a way nobody would notice: the run still writes
    /// exactly what it should, and only the warnings are junk.
    ///
    /// The two sides are spelled by different means -- one built from a calendar
    /// entry and the root the run was given, the other returned by a glob -- so
    /// they are compared by what identifies a round rather than by the string
    /// they arrived as. `roundKey` is that identity, and it survives a trailing
    /// slash on the root, a `./` in the middle, and an absolute path meeting a
    /// relative one.
    pub def detect(tasks: List[FileTask.FileTask], found: List[String]): List[String] =
        let listed = tasks |> List.map(task -> roundKey(task#inputPath));
        found |> List.filter(path -> not List.memberOf(roundKey(path), listed))

    /// A CSV's round identity: the directory it sits in and the file it is.
    ///
    /// Two segments and no more. Everything above them is where the run was
    /// pointed, which both sides already agree on by construction and neither
    /// spells the same way.
    ///
    /// A file directly under the root, or nested deeper than a season directory,
    /// gets a key no entry can match -- which is the right answer: no round is
    /// filed there.
    pub def roundKey(path: String): (String, String) =
        match String.split({regex = "/"}, path) |> List.filter(seg -> seg != "" and seg != ".") |> List.reverse {
            case name :: dir :: _ => (dir, name)
            case name :: Nil      => ("", name)
            case Nil              => ("", "")
        }

}
