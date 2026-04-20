def main(): Unit \ IO =
    let inputPath = "../cli/test_data.csv";
    let outputPath = "../cli/test_data.json";
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
