mod Cli.Stages.Output {

    use Util.Files
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Stages.Transform.Rendered

    /// Writes the rendered metadata and laps JSON to the paths
    /// specified on the FileTask. Returns the first I/O failure.
    pub def writeOutputs(task: FileTask.FileTask, rendered: Rendered): Result[CliError, Unit] \ IO =
        forM(
            _ <- Files.writeFile(task#outputPath, rendered#metadataJson) |> Result.mapErr(CliError.File);
            _ <- Files.writeFile(task#lapsPath, rendered#lapsJson) |> Result.mapErr(CliError.File)
        ) yield ()

}
