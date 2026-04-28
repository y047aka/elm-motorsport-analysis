/// 汎用ファイル I/O ユーティリティ。エラーは `Util` 内で完結する独自型
/// `FileError` で表現し、CLI レイヤや特定アプリのエラー型には依存しない
/// (依存方向は Cli → Util の片方向のみ)。
pub mod Util.Files {

    /// ファイル I/O 操作で発生しうる低レベルエラー。CLI 側はこれを
    /// `Cli.Errors.CliError.File(_)` でラップして扱う。
    pub enum FileError with ToString {
        case ReadError(String, String)   // path, underlying message
        case WriteError(String, String)
        case AccessError(String)         // path stat / existence の取得失敗
        case ListDirError(String)
    }

    pub def readLines(path: String): Result[FileError, List[String]] \ IO =
        Fs.FileRead.runWithIO(() ->
            Fs.ReadLines.runWithFileRead(() ->
                Fs.ReadLines.readLines(path)
            )
        ) |> Result.mapErr(e -> FileError.ReadError(path, "${e}"))

    pub def writeFile(path: String, content: String): Result[FileError, Unit] \ IO =
        Fs.FileWrite.runWithIO(() ->
            Fs.WriteFile.runWithFileWrite(() ->
                Fs.WriteFile.write({str = content}, path)
            )
        ) |> Result.mapErr(e -> FileError.WriteError(path, "${e}"))

    pub def exists(path: String): Result[FileError, Bool] \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.exists(path))
            |> Result.mapErr(e -> FileError.AccessError("${e}"))

    pub def isDirectory(path: String): Result[FileError, Bool] \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.isDirectory(path))
            |> Result.mapErr(e -> FileError.AccessError("${e}"))

    pub def listDir(path: String): Result[FileError, List[String]] \ IO =
        Fs.DirList.runWithIO(() -> Fs.DirList.list(path))
            |> Result.mapErr(e -> FileError.ListDirError("${e}"))

    /// 指定ディレクトリ配下を再帰的に走査し、`.csv` で終わるファイルパスを
    /// すべて返す。サブディレクトリには深さ制限なしで降りる。
    pub def walkCsvFiles(dirPath: String): Result[FileError, List[String]] \ IO =
        forM(
            entries <- listDir(dirPath);
            result  <- gatherCsvs(dirPath, entries)
        ) yield result

    def gatherCsvs(dirPath: String, entries: List[String]): Result[FileError, List[String]] \ IO =
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
