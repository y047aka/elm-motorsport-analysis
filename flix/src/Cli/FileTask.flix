mod Cli.FileTask {

    use Motorsport.Calendar
    use Motorsport.Calendar.Entry

    /// One round's CSV, built from a calendar entry and the directory the run
    /// reads from. The calendar names the round and the path follows, so there
    /// is nothing to read back off a directory name.
    pub type alias Input = {
        inputPath = String,
        entry     = Entry
    }

    /// One round's files, as `Input` is its CSV, under the directory the run
    /// writes to. `directory` is the season's, which a season no run has
    /// written before does not have yet.
    pub type alias Output = {
        directory    = String,
        outputPath   = String,
        lapsPath     = String,
        timelinePath = String,
        entry        = Entry
    }

    /// Which of the calendar's rounds a stage is for.
    pub enum Rounds with Eq, ToString {
        case Every
        case Only(List[(Int32, String)])
    }

    /// Every round the calendar holds, under `root`. A CSV no entry names is
    /// not here, so it is never read; `Cli.Load.Unlisted` reports those.
    pub def inputs(root: String): List[Input] =
        Calendar.entries() |> List.map(entry ->
            { inputPath = "${stem(root, entry)}.csv", entry = entry }
        )

    /// The rounds `rounds` names, under `root`. Every name is a round
    /// `Cli.Args` has already found on the calendar, so there is nothing here
    /// to fail.
    pub def outputs(root: String, rounds: Rounds): List[Output] =
        Calendar.entries()
            |> List.filter(entry -> match rounds {
                case Rounds.Every       => true
                case Rounds.Only(names) => List.memberOf((entry#season, entry#id), names)
            })
            |> List.map(entry -> {
                let s = stem(root, entry);
                {
                    directory    = seasonDirectory(root, entry),
                    outputPath   = "${s}.json",
                    lapsPath     = "${s}_laps.jsonl",
                    timelinePath = "${s}_timeline.jsonl",
                    entry        = entry
                }
            })

    def seasonDirectory(root: String, entry: Entry): String =
        "${root}/${entry#season}"

    /// How a round is named in the run's output. The display name would not say
    /// which of two seasons a line is about.
    pub def label(task: { entry = Entry | r }): String =
        "${task#entry#season}/${task#entry#id}"

    def stem(root: String, entry: Entry): String =
        "${seasonDirectory(root, entry)}/${entry#id}"

}
