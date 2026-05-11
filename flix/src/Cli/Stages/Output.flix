mod Cli.Stages.Output {

    use Util.Files
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Stages.Transform.Output

    /// Writes the transformed metadata and laps JSON to the paths
    /// specified on the FileTask. Returns the first I/O failure.
    pub def writeOutputs(task: FileTask.FileTask, output: Output): Result[CliError, Unit] \ IO =
        forM(
            _ <- Files.writeFile(task#outputPath, output#metadataJson) |> Result.mapErr(CliError.File);
            _ <- Files.writeFile(task#lapsPath, output#lapsJson) |> Result.mapErr(CliError.File)
        ) yield ()

}
