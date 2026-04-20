def main(): Unit \ IO =
    let path = "../cli/test_data.csv";
    let result = Fs.FileRead.runWithIO(() ->
        Fs.ReadLines.runWithFileRead(() ->
            Fs.ReadLines.readLines(path)
        )
    );
    match result {
        case Ok(lines) =>
            let count = List.length(lines);
            println("File: ${path}");
            println("Lines: ${count}")
        case Err(e) =>
            println("Error: ${e}")
    }
