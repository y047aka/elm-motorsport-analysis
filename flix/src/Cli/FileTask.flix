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

    /// Which of the calendar's rounds a stage is for.
    pub enum Rounds with Eq, ToString {
        case Every
        case Only(List[(Int32, String)])
    }

    /// Every round the calendar holds, under `root`. A CSV no entry names is
    /// not here, so it is never read; `Cli.Load.Unlisted` reports those.
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

    /// The tasks `rounds` names, or the names no round on the calendar answers
    /// to. A name nothing matches is an error rather than an empty worklist:
    /// the round it asks for does not exist.
    pub def selected(root: String, rounds: Rounds): Result[List[String], List[FileTask]] =
        match rounds {
            case Rounds.Every       => Ok(fromCalendar(root))
            case Rounds.Only(names) =>
                let tasks = fromCalendar(root);
                match List.filter(name -> not List.exists(covers(name), tasks), names) {
                    case Nil      => Ok(List.filter(task -> List.exists(name -> covers(name, task), names), tasks))
                    case unlisted => Err(List.map(display, unlisted))
                }
        }

    /// How a round is named in the run's output. The display name would not say
    /// which of two seasons a line is about.
    pub def label(task: FileTask): String =
        "${task#entry#season}/${task#entry#id}"

    def covers(name: (Int32, String), task: FileTask): Bool =
        let (season, id) = name;
        task#entry#season == season and task#entry#id == id

    def display(name: (Int32, String)): String =
        let (season, id) = name;
        "${season}/${id}"

}
