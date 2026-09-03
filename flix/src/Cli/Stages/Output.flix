mod Cli.Stages.Output {

    use Util.Files
    use Cli.Errors.CliError
    use Cli.FileTask
    use Round.Render.Rendered

    pub def write(task: FileTask.FileTask, rendered: Rendered): Result[CliError, Unit] \ IO =
        forM(
            _ <- Files.write(task#outputPath, rendered#metadataJson) |> Result.mapErr(CliError.File);
            _ <- Files.write(task#lapsPath, rendered#lapsJsonl) |> Result.mapErr(CliError.File)
        ) yield ()

}
