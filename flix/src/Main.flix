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
    let readResult = Fs.FileRead.runWithIO(() ->
        Fs.ReadLines.runWithFileRead(() ->
            Fs.ReadLines.readLines(task#inputPath)
        )
    );
    match readResult {
        case Ok(lines) =>
            match lines {
                case _header :: dataLines =>
                    let records = Csv.parseLines(dataLines);
                    let json = Json.render(Lap.toJsonArray(records));
                    let writeResult = Fs.FileWrite.runWithIO(() ->
                        Fs.WriteFile.runWithFileWrite(() ->
                            Fs.WriteFile.write({str = json}, task#outputPath)
                        )
                    );
                    match writeResult {
                        case Ok(_)  => println("${task#eventName}: Written to ${task#outputPath}")
                        case Err(e) => println("${task#eventName}: Write error: ${e}")
                    }
                case Nil =>
                    println("${task#eventName}: Empty file")
            }
        case Err(e) =>
            println("${task#eventName}: Read error: ${e}")
    }
