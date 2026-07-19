///
/// The crates.io registry as an algebraic effect.
///
/// `rust-major-audit` asks "what is the latest published version of this
/// crate?" — that question is the effect; shelling out to `cargo search`
/// is the one real handler (`runWithIO`). Tests can answer from a table
/// instead, the same way `FileIO` is served from memory.
///
mod DepsAudit.Crates {

    use DepsAudit.RustMajor

    pub eff CrateRegistry {

        /// Latest published version of a crate (`None` when unknown).
        def latest(name: String): Option[String]

    }

    /// Handle `CrateRegistry` with `cargo search` against crates.io.
    pub def runWithIO(f: Unit -> a \ ef): a \ (ef - CrateRegistry) + IO =
        run { f() } with handler CrateRegistry {
            def latest(name, k) = k(fetchLatestCrate(name))
        }

    /// Latest version of a crate via `cargo search <name> --limit 1`.
    ///
    /// Runs through `sh -c` so stderr can be discarded by the shell: draining
    /// only stdout from Flix would deadlock if a chatty stderr (cargo prints
    /// "Updating crates.io index" there) filled its pipe buffer. Crate names
    /// are `[\w-]+` per `RustMajor.parseDeps`, so they need no shell quoting.
    def fetchLatestCrate(name: String): Option[String] \ IO =
        Sys.Process.runWithIO(() ->
            match Sys.Process.exec("sh", "-c" :: "cargo search ${name} --limit 1 2>/dev/null" :: Nil) {
                case Err(_) => None
                case Ok(ph) =>
                    let out = match Sys.Process.stdout(ph) {
                        case Ok(so) => readAllStdOut(so)
                        case Err(_) => ""
                    };
                    let _ = Sys.Process.waitFor(ph);
                    RustMajor.parseSearchOutput(name, out)
            })

    /// Drain a process's stdout into a string.
    def readAllStdOut(so: Sys.StdOut.StdOut): String \ IO = region rc {
        // Chunks are collected in reverse and flattened once, so appending
        // stays linear rather than quadratic.
        def loop(chunks) = {
            let buf = Array.repeat(rc, 4096, 0i8);
            match Readable.read(buf, so) {
                case Ok(n) =>
                    if (n > 0)
                        loop((Array.slice(rc, start = 0, end = n, buf) |> Array.toList) :: chunks)
                    else
                        chunks
                case Err(_) => chunks
            }
        };
        loop(Nil) |> List.reverse |> List.flatten |> List.toVector |> String.fromBytes
    }

}
