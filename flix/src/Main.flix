def main(): Unit \ IO =
    let path = "../cli/test_data.csv";
    let result = Fs.FileRead.runWithIO(() ->
        Fs.ReadLines.runWithFileRead(() ->
            Fs.ReadLines.readLines(path)
        )
    );
    match result {
        case Ok(lines) =>
            match lines {
                case _header :: dataLines =>
                    let records = Csv.parseLines(dataLines);
                    println(Csv.formatTable(records))
                case Nil =>
                    println("Empty file")
            }
        case Err(e) =>
            println("Error: ${e}")
    }
