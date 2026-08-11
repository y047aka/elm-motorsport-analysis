mod Cli.FileTask {

    use Motorsport.Calendar
    use Motorsport.Calendar.Entry

    /// One round's files, built from a calendar entry and the root the run was
    /// pointed at. The calendar names the round and the path follows, so there
    /// is nothing to read back off a directory name.
    pub type alias FileTask = {
        inputPath  = String,
        outputPath = String,
        lapsPath   = String,
        entry      = Entry
    }

    /// Every round the calendar holds, under `root`. A CSV no entry names is
    /// not here, so it is never read; `Cli.Stages.Unlisted` reports those.
    pub def fromCalendar(root: String): List[FileTask] =
        Calendar.entries() |> List.map(entry -> {
            let stem = "${root}/${entry#season}/${entry#id}";
            {
                inputPath  = "${stem}.csv",
                outputPath = "${stem}.json",
                lapsPath   = "${stem}_laps.jsonl",
                entry      = entry
            }
        })

    /// How a round is named in the run's output. The display name would not say
    /// which of two seasons a line is about.
    pub def label(task: FileTask): String =
        "${task#entry#season}/${task#entry#id}"

}
