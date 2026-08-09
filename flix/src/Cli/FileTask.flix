mod Cli.FileTask {

    use Motorsport.Calendar
    use Motorsport.Calendar.Entry

    /// One round's files. Every one of these is built from a calendar entry and
    /// the root the run was pointed at, so none of it is read back off a path.
    ///
    /// The season used to be parsed out of the directory the CSV was filed
    /// under, because that was the only place the year was written down. Working
    /// the other way round -- the calendar names the round, the path follows --
    /// leaves nothing to parse and nothing to disagree about.
    pub type alias FileTask = {
        inputPath  = String,
        outputPath = String,
        lapsPath   = String,
        entry      = Entry
    }

    /// Every round the calendar holds, under `root`.
    ///
    /// A CSV under `root` that no entry names is not in this list, so it is
    /// never read and nothing is written for it. `Cli.Stages` reports those
    /// separately -- ignored is not the same as unnoticed.
    pub def fromCalendar(root: String): List[FileTask] =
        Calendar.entries() |> List.map(entry -> {
            let stem = "${root}/${entry#season}/${entry#id}";
            {
                inputPath  = "${stem}.csv",
                outputPath = "${stem}.json",
                lapsPath   = "${stem}_laps.json",
                entry      = entry
            }
        })

    /// What the round is called in the run's own output. The display name is the
    /// round's; this is the file's, and a log line has to say which file.
    pub def label(task: FileTask): String =
        "${task#entry#season}/${task#entry#id}"

}
