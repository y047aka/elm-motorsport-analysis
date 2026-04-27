mod Cli {

    import java.lang.System

    pub enum CliError with ToString {
        case PathNotFound(String)
        case PathAccessError(String)
        case ListDirError(String)
        case NoCsvFiles(String)
        case OutputWithDirectory
        case ReadFile(String, String)
        case EmptyFile(String)
        case WriteFile(String, String)
    }

    /// JVM を即時終了。`def main(): Int32` で値を返しても stdout に印字
    /// されるだけで OS exit code にならないため、明示的に呼ぶ必要がある。
    pub def exit(code: Int32): Unit \ IO =
        System.exit(code)

}
