use Sys.Console
use Sys.Env
use Sys.Exit
use Time.Clock
use Time.TimeUnit

use DepsAudit.Cli
use DepsAudit.Elm
use DepsAudit.ElmPages
use DepsAudit.Io
use DepsAudit.Nix
use DepsAudit.Npm
use DepsAudit.RustAudit
use DepsAudit.RustMajor

///
/// deps-audit: audit helpers for the update-deps skill.
///
/// Every subcommand is a `Cli.Output`-returning function: it computes what
/// belongs on stdout, on stderr, and in the exit code, and returns that as
/// data. `main` performs the single `Cli.emit` that touches the terminal.
///
/// Within a subcommand, fallible steps chain with `forM`/`yield` over
/// `Result[String, _]` — the type every `Io.*` and `DepsAudit.*` rendering
/// function already returns — so the steps read top-to-bottom in the order
/// they run, with failure handled once at the boundary rather than at each
/// step.
///
def main(): Unit \ {Env, IO, Exit, Console, Clock} =
    Exit.exit(Cli.emit(route(Env.getArgs())))

def route(args: List[String]): Cli.Output \ {IO, Console, Clock, Env} =
    match args {
        case cmd :: Nil => dispatch(cmd)
        case _          => usage()
    }

def dispatch(cmd: String): Cli.Output \ {IO, Console, Clock, Env} =
    match cmd {
        case "rust-minor-audit"       => cmdRustMinorAudit()
        case "nix-channel-audit"      => cmdNixChannelAudit()
        case "nix-flakelock-audit"    => cmdNixFlakelockAudit()
        case "elm-versions-report"    => cmdElmVersionsReport()
        case "elm-pages-elm-guard"    => cmdElmPagesElmGuard()
        case "elm-pages-vite-version" => cmdElmPagesViteVersion()
        case "elm-pages-compat-key"   => cmdElmPagesCompatKey()
        case "elm-pages-audit"        => cmdElmPagesAudit()
        case "npm-outdated-audit"     => cmdNpmOutdatedAudit()
        case "npm-security-audit"     => cmdNpmSecurityAudit()
        case "rust-major-audit"       => cmdRustMajorAudit()
        case "npm-pin-versions"       => cmdNpmPinVersions()
        case _                        => usage()
    }

// --- nix ---

def cmdNixChannelAudit(): Cli.Output \ {IO, Clock} =
    let now = Clock.currentTime(TimeUnit.Seconds);
    Cli.fromResult(forM (
        content <- Io.readFile("flake.nix")
    ) yield Nix.renderChannelAudit(content, now))

def cmdNixFlakelockAudit(): Cli.Output \ IO =
    Cli.fromResult(forM (
        content <- Io.readFile("flake.lock");
        body    <- Nix.renderFlakelockAudit(content)
    ) yield body)

// --- elm ---

def cmdElmVersionsReport(): Cli.Output \ IO =
    Cli.traverseUntilFailure(reportOneElmJson, "app/elm.json" :: "package/elm.json" :: Nil)

/// One elm.json's section, followed by the blank line that separates files.
def reportOneElmJson(f: String): Cli.Output \ IO =
    Cli.fromResultWith(body -> Cli.ok(body :: "" :: Nil), forM (
        raw  <- Io.readFile(f);
        body <- Elm.renderVersionsReport(f, raw)
    ) yield body)

// --- elm-pages ---

def cmdElmPagesElmGuard(): Cli.Output \ IO =
    Cli.fromResult(forM (
        raw  <- Io.readFile("app/elm.json");
        body <- ElmPages.renderElmGuard(raw)
    ) yield body)

def cmdElmPagesViteVersion(): Cli.Output \ IO =
    let path = bundledVitePackageJsonPath();
    Cli.fromResult(forM (
        raw     <- Io.readFile(path);
        version <- ElmPages.renderViteVersion(path, raw)
    ) yield version)

def cmdElmPagesCompatKey(): Cli.Output \ {IO, Env} =
    ElmPages.renderCompatKeyStandalone(ElmPages.resolveCompatKey())

def cmdElmPagesAudit(): Cli.Output \ {IO, Console, Env} =
    let latest = optionFromTrimmed(Cli.readStdin());
    Cli.fromResult(forM (
        pkgRaw          <- Io.readFile("app/package.json");
        versionSection  <- ElmPages.renderAuditVersionSection(pkgRaw, latest);
        elmJsonRaw      <- Io.readFile("app/elm.json");
        packagesSection <- ElmPages.renderAuditPackagesSection(elmJsonRaw)
    ) yield "${versionSection}\n\n${packagesSection}\n\n--- compatibilityKey ---")
        |> Cli.andThen(() -> ElmPages.renderCompatKeyForAudit(ElmPages.resolveCompatKey()))

// --- npm ---

def cmdNpmOutdatedAudit(): Cli.Output \ {IO, Console} =
    let input = String.trim(Cli.readStdin());
    if (input == "")
        Cli.okText(Npm.emptyOutdatedReport())
    else
        Cli.fromResultWith(match (report, vite) ->
            Cli.okText(report) |> Cli.andThen(() -> viteSection(vite)),
            Npm.renderOutdatedAudit(input))

/// The trailing vite section, which needs the bundled vite's version off
/// disk. Absent when npm outdated reported no vite entry.
def viteSection(vite: Option[(String, String)]): Cli.Output \ IO =
    match vite {
        case None => Cli.empty()
        case Some((current, latest)) =>
            let bundledMajor = match Io.readFile(bundledVitePackageJsonPath()) {
                case Ok(raw) => Npm.bundledMajorFromPackageJson(raw)
                case Err(_)  => "unknown"
            };
            Cli.okText(Npm.renderViteSection(current, latest, bundledMajor))
    }

def cmdNpmSecurityAudit(): Cli.Output \ Console =
    let input = String.trim(Cli.readStdin());
    if (input == "")
        Cli.okText(Npm.emptySecurityReport())
    else
        Cli.fromResult(Npm.renderSecurityAudit(input))

def cmdNpmPinVersions(): Cli.Output \ IO =
    Cli.fromResultWith(lock -> Cli.traverseUntilFailure(pinOneWorkspace(lock), Npm.pinWorkspaces()), forM (
        lockRaw <- Io.readFile("package-lock.json");
        lock    <- Util.Json.parse(lockRaw) |> Result.mapErr(e -> "package-lock.json: ${e}")
    ) yield lock)

/// Read, pin, and write back one workspace's package.json. Prints nothing
/// on success — the rewritten file is the result.
def pinOneWorkspace(lock: Util.Json.Json, workspace: (String, String)): Cli.Output \ IO =
    let (file, wsPrefix) = workspace;
    Cli.fromResultWith(_ -> Cli.empty(), forM (
        raw     <- Io.readFile(file);
        updated <- Npm.pinFile(file, raw, lock, wsPrefix);
        _       <- Io.writeFile(file, updated)
    ) yield ())

// --- rust ---

def cmdRustMinorAudit(): Cli.Output \ Console =
    Cli.okText(RustAudit.renderMinorAudit(Cli.readStdin()))

def cmdRustMajorAudit(): Cli.Output \ IO =
    let contents = RustMajor.cargoTomlFiles()
        |> List.filterMap(f -> Io.readFile(f) |> Result.toOption);
    let resolved = RustMajor.parseDeps(contents)
        |> List.map(match (name, constraint) -> (name, constraint, fetchLatestCrate(name)));
    Cli.okText(RustMajor.renderMajorAudit(resolved))

// --- shared helpers ---

/// The bundled (nested) vite package.json, falling back to the hoisted one.
def bundledVitePackageJsonPath(): String \ IO =
    let candidates = ElmPages.vitePackageJsonCandidates();
    candidates
        |> List.find(p -> Io.exists(p))
        |> Option.getWithDefault(List.last(candidates) |> Option.getWithDefault(""))

/// `None` for blank/whitespace-only input, `Some` otherwise — the shape
/// `elm-pages-audit` needs for the "latest version from stdin" argument.
def optionFromTrimmed(s: String): Option[String] =
    let trimmed = String.trim(s);
    if (trimmed == "") None else Some(trimmed)

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

def usage(): Cli.Output =
    Cli.failLines(
        "usage: deps-audit <subcommand>" ::
        "" ::
        "subcommands:" ::
        "  npm-security-audit" ::
        "  npm-outdated-audit" ::
        "  npm-pin-versions" ::
        "  elm-versions-report" ::
        "  elm-pages-audit" ::
        "  elm-pages-compat-key" ::
        "  elm-pages-elm-guard" ::
        "  elm-pages-vite-version" ::
        "  rust-major-audit" ::
        "  rust-minor-audit" ::
        "  nix-channel-audit" ::
        "  nix-flakelock-audit" :: Nil)
