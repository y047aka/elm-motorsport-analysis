pub mod Cli.Exit {

    import java.lang.System

    // `def main(): Int32` の戻り値は OS exit code にならず stdout に印字されるだけのため、
    // System.exit で明示的に終了する必要がある。
    pub def exit(code: Int32): Unit \ IO =
        System.exit(code)

}
