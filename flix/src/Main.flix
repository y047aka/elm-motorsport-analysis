use Sys.Env
use Cli.CliError

pub type alias ProcessingReport = {
    lapCount = Int32,
    outputPath = String
}

pub type alias RunSummary = {
    processed = Int32,
    errors = Int32
}

def main(): Unit \ {Env, IO} =
    let args = Env.getArgs();
    let code = match Args.parse(args) {
        case Err(e) =>
            Log.error("Error: ${e}");
            Log.error("Usage: flix-run <input.csv|dir> [--output <output.json>]");
            1
        case Ok(parsed) =>
            match FileTask.resolve(parsed) {
                case Err(e) =>
                    Log.error("Error: ${e}");
                    1
                case Ok(tasks) =>
                    let summary = runTasks(tasks);
                    Log.info("Processing completed: ${summary#processed} processed, ${summary#errors} errors");
                    summaryExitCode(summary)
            }
    };
    Cli.exit(code)

def runTasks(tasks: List[FileTask.FileTask]): RunSummary \ IO =
    List.foldLeft(
        (summary, task) -> match processFile(task) {
            case Ok(report) =>
                Log.info("${task#eventName}: Wrote ${report#lapCount} laps to ${report#outputPath}");
                { processed = summary#processed + 1, errors = summary#errors }
            case Err(e) =>
                Log.error("${task#eventName}: ${e}");
                { processed = summary#processed, errors = summary#errors + 1 }
        },
        { processed = 0, errors = 0 },
        tasks
    )

def processFile(task: FileTask.FileTask): Result[CliError, ProcessingReport] \ IO =
    let inputPath = task#inputPath;
    let outputPath = task#outputPath;
    forM(
        lines     <- Files.readLines(inputPath);
        dataLines <- match lines {
                        case _ :: rest => Ok(rest)
                        case Nil       => Err(CliError.EmptyFile(inputPath))
                     };
        processed <- Ok(Stages.process(dataLines));
        _         <- Files.writeFile(outputPath, processed#json)
    ) yield {
        lapCount   = processed#lapCount,
        outputPath = outputPath
    }

def summaryExitCode(summary: RunSummary): Int32 =
    if (summary#errors == 0) 0 else 1
