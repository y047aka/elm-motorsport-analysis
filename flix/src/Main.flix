use Sys.Env

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

def processFile(task: FileTask.FileTask): Result[String, ProcessingReport] \ IO =
    forM(
        lines     <- Fs.FileRead.runWithIO(() ->
                        Fs.ReadLines.runWithFileRead(() ->
                            Fs.ReadLines.readLines(task#inputPath)
                     )) |> Result.mapErr(e -> "Read error: ${e}");
        dataLines <- match lines {
                        case _ :: rest => Ok(rest)
                        case Nil       => Err("Empty file")
                     };
        processed <- Ok(Pipeline.process(dataLines));
        _         <- Fs.FileWrite.runWithIO(() ->
                        Fs.WriteFile.runWithFileWrite(() ->
                            Fs.WriteFile.write({str = processed#json}, task#outputPath)
                        )
                     ) |> Result.mapErr(e -> "Write error: ${e}")
    ) yield {
        lapCount   = processed#lapCount,
        outputPath = task#outputPath
    }
