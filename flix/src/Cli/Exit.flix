/// JVM プロセス終了処理。`Cli.Main` の `def main` が最後に終了コードを
/// 渡して呼び出す。
pub mod Cli.Exit {

    import java.lang.System

    /// JVM を即時終了。`def main(): Int32` で値を返しても stdout に印字
    /// されるだけで OS exit code にならないため、明示的に呼ぶ必要がある。
    pub def exit(code: Int32): Unit \ IO =
        System.exit(code)

}
