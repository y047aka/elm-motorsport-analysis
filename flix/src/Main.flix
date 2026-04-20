use Sys.Env

def main(): Unit \ {Env, IO} =
    let args = Env.getArgs();
    match Args.parse(args) {
        case Err(e) =>
            println("Error: ${e}");
            println("Usage: flix-run <input.csv> [--output <output.json>]")
        case Ok(parsed) =>
            convert(parsed#inputPath, parsed#outputPath)
    }

def convert(inputPath: String, outputPath: String): Unit \ IO =
    let readResult = Fs.FileRead.runWithIO(() ->
        Fs.ReadLines.runWithFileRead(() ->
            Fs.ReadLines.readLines(inputPath)
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
                            Fs.WriteFile.write({str = json}, outputPath)
                        )
                    );
                    match writeResult {
                        case Ok(_)  => println("Written to ${outputPath}")
                        case Err(e) => println("Write error: ${e}")
                    }
                case Nil =>
                    println("Empty file")
            }
        case Err(e) =>
            println("Read error: ${e}")
    }
