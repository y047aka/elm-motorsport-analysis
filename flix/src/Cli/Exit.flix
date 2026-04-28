mod Cli.Exit {

    import java.lang.System

    // The return value of `def main(): Int32` is printed to stdout rather than used as
    // the OS exit code, so System.exit must be called explicitly.
    pub def exit(code: Int32): Unit \ IO =
        System.exit(code)

}
