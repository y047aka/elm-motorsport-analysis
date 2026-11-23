/// A circuit's map record read from where the app is served it, for the commands that lay
/// a geometry or a report from its figures. What the record says is `Circuit.figuresOf`'s
/// to read; this is the file.
pub mod MapRecord {

    use Circuit.Circuit
    use Circuit.Figures

    /// The figures of a circuit's map, or the sentence naming the record that would not
    /// give them.
    pub def read(circuit: Circuit): Result[String, Figures] \ IO =
        let path = Circuit.mapOf(circuit);
        Cli.Errors.readFile(path)
            |> Result.mapErr(problem -> "${problem}")
            |> Result.flatMap(text -> Circuit.figuresOf(text) |> Result.mapErr(problem -> "${path}: ${problem}"))

}
