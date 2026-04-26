use Sys.Env

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
    let result = forM(
        lines     <- Fs.FileRead.runWithIO(() ->
                        Fs.ReadLines.runWithFileRead(() ->
                            Fs.ReadLines.readLines(task#inputPath)
                     )) |> Result.mapErr(e -> "Read error: ${e}");
        dataLines <- match lines {
                        case _ :: rest => Ok(rest)
                        case Nil       => Err("Empty file")
                     };
        json      <- Ok(Pipeline.process(dataLines));
        _         <- Fs.FileWrite.runWithIO(() ->
                        Fs.WriteFile.runWithFileWrite(() ->
                            Fs.WriteFile.write({str = json}, task#outputPath)
                        )
                     ) |> Result.mapErr(e -> "Write error: ${e}")
    ) yield ();
    match result {
        case Ok(_)  => println("${task#eventName}: Written to ${task#outputPath}")
        case Err(e) => println("${task#eventName}: ${e}")
    }
