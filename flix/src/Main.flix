use Sys.Env
use Cli.CliError

pub type alias ProcessingReport = {
    lapCount = Int32,
    outputPath = String
}

def main(): Unit \ {Env, IO} =
    let args = Env.getArgs();
    match Args.parse(args) {
        case Err(e) =>
            println("Error: ${e}");
            println("Usage: flix-run <input.csv|dir> [--output <output.json>]")
        case Ok(parsed) =>
            match FileTask.resolve(parsed) {
                case Err(e) =>
                    println("Error: ${e}")
                case Ok(tasks) =>
                    List.forEach(convert, tasks)
            }
    }

def convert(task: FileTask.FileTask): Unit \ IO =
    match processFile(task) {
        case Ok(report) =>
            println("${task#eventName}: Wrote ${report#lapCount} laps to ${report#outputPath}")
        case Err(e) =>
            println("${task#eventName}: ${e}")
    }

def processFile(task: FileTask.FileTask): Result[CliError, ProcessingReport] \ IO =
    let inputPath = task#inputPath;
    let outputPath = task#outputPath;
    forM(
        lines     <- Fs.FileRead.runWithIO(() ->
                        Fs.ReadLines.runWithFileRead(() ->
                            Fs.ReadLines.readLines(inputPath)
                     )) |> Result.mapErr(e -> CliError.ReadFile(inputPath, "${e}"));
        dataLines <- match lines {
                        case _ :: rest => Ok(rest)
                        case Nil       => Err(CliError.EmptyFile(inputPath))
                     };
        processed <- Ok(Pipeline.process(dataLines));
        _         <- Fs.FileWrite.runWithIO(() ->
                        Fs.WriteFile.runWithFileWrite(() ->
                            Fs.WriteFile.write({str = processed#json}, outputPath)
                        )
                     ) |> Result.mapErr(e -> CliError.WriteFile(outputPath, "${e}"))
    ) yield {
        lapCount   = processed#lapCount,
        outputPath = outputPath
    }
