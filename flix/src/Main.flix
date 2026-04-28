use Sys.Env
use Cli.Args
use Cli.Errors.CliError
use Cli.Exit
use Cli.FileTask
use Cli.Log
use Cli.Stages
use Util.Files

pub type alias ProcessingReport = {
    lapCount = Int32,
    outputPath = String,
    lapsPath = String
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
    Exit.exit(code)

def runTasks(tasks: List[FileTask.FileTask]): RunSummary \ IO =
    List.foldLeft(
        (summary, task) -> match processFile(task) {
            case Ok(report) =>
                Log.info("${task#eventName}: Wrote ${report#lapCount} laps");
                Log.info("${task#eventName}: Metadata -> ${report#outputPath}");
                Log.info("${task#eventName}: Laps     -> ${report#lapsPath}");
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
    let lapsPath = task#lapsPath;
    let eventName = task#eventName;
    forM(
        lines     <- Files.readLines(inputPath) |> Result.mapErr(CliError.File);
        dataLines <- match lines {
                        case _ :: rest => Ok(rest)
                        case Nil       => Err(CliError.EmptyFile(inputPath))
                     };
        processed <- Ok(Stages.process(eventName, dataLines));
        _         <- Files.writeFile(outputPath, processed#metadataJson) |> Result.mapErr(CliError.File);
        _         <- Files.writeFile(lapsPath, processed#lapsJson) |> Result.mapErr(CliError.File)
    ) yield {
        lapCount   = processed#lapCount,
        outputPath = outputPath,
        lapsPath   = lapsPath
    }

def summaryExitCode(summary: RunSummary): Int32 =
    if (summary#errors == 0) 0 else 1
