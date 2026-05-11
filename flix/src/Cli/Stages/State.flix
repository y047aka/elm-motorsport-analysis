mod Cli.Stages.State {

    use Cli.FileTask
    use RawLap.RawLap

    /// Rendered JSON payloads produced by the Transform stage.
    pub type alias Rendered = {
        lapCount     = Int32,
        metadataJson = String,
        lapsJson     = String
    }

    /// Pipeline state threaded through every stage of processFile.
    /// Each stage has the uniform shape `State -> Result[CliError, State]`
    /// (or `State -> State` for pure stages) so the pipeline can be
    /// composed with `|>` alone.
    pub type alias State = {
        task     = FileTask.FileTask,
        rawLaps  = List[RawLap],
        rendered = Rendered
    }

    pub def init(task: FileTask.FileTask): State = {
        task     = task,
        rawLaps  = Nil,
        rendered = { lapCount = 0, metadataJson = "", lapsJson = "" }
    }

}
