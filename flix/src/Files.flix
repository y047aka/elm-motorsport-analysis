mod Files {

    use Cli.CliError

    pub def readLines(path: String): Result[CliError, List[String]] \ IO =
        Fs.FileRead.runWithIO(() ->
            Fs.ReadLines.runWithFileRead(() ->
                Fs.ReadLines.readLines(path)
            )
        ) |> Result.mapErr(e -> CliError.ReadFile(path, "${e}"))

    pub def writeFile(path: String, content: String): Result[CliError, Unit] \ IO =
        Fs.FileWrite.runWithIO(() ->
            Fs.WriteFile.runWithFileWrite(() ->
                Fs.WriteFile.write({str = content}, path)
            )
        ) |> Result.mapErr(e -> CliError.WriteFile(path, "${e}"))

    pub def exists(path: String): Result[CliError, Bool] \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.exists(path))
            |> Result.mapErr(e -> CliError.PathAccessError("${e}"))

    pub def isDirectory(path: String): Result[CliError, Bool] \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.isDirectory(path))
            |> Result.mapErr(e -> CliError.PathAccessError("${e}"))

    pub def listDir(path: String): Result[CliError, List[String]] \ IO =
        Fs.DirList.runWithIO(() -> Fs.DirList.list(path))
            |> Result.mapErr(e -> CliError.ListDirError("${e}"))

    /// 指定ディレクトリ配下を再帰的に走査し、`.csv` で終わるファイルパスを
    /// すべて返す。サブディレクトリには深さ制限なしで降りる。
    pub def walkCsvFiles(dirPath: String): Result[CliError, List[String]] \ IO =
        forM(
            entries <- listDir(dirPath);
            result  <- gatherCsvs(dirPath, entries)
        ) yield result

    def gatherCsvs(dirPath: String, entries: List[String]): Result[CliError, List[String]] \ IO =
        match entries {
            case Nil => Ok(Nil)
            case e :: rest =>
                let fullPath = "${dirPath}/${e}";
                forM(
                    isDir <- isDirectory(fullPath);
                    head  <- if (isDir) walkCsvFiles(fullPath)
                             else if (String.endsWith({suffix = ".csv"}, fullPath)) Ok(fullPath :: Nil)
                             else Ok(Nil);
                    tail  <- gatherCsvs(dirPath, rest)
                ) yield List.append(head, tail)
        }

}
