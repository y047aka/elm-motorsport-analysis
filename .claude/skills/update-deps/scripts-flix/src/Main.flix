use Sys.Console
use Sys.Env
use Sys.Exit
use Time.Clock
use Time.TimeUnit

use DepsAudit.Elm
use DepsAudit.ElmPages
use DepsAudit.Io
use DepsAudit.Nix
use DepsAudit.Npm
use DepsAudit.Report
use DepsAudit.RustAudit
use DepsAudit.RustMajor

///
/// deps-audit: audit helpers for the update-deps skill.
///
/// Flix port of the Rust implementation in ../scripts. Each `cmdXxx`
/// handler chains its steps with `forM`/`yield` over `Result[String, _]`
/// (every `Io.*` and `DepsAudit.*` rendering function already returns that
/// type), so the steps read top-to-bottom in the order they execute, with
/// a single `Err`/`Ok` match at the end rather than one nested per step.
///
def main(): Unit \ {Env, IO, Exit, Console, Clock} =
    let code = match Env.getArgs() {
        case cmd :: Nil => dispatch(cmd)
        case _          => usage()
    };
    Exit.exit(code)

def dispatch(cmd: String): Int32 \ {IO, Console, Clock, Env} =
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

def cmdRustMinorAudit(): Int32 \ Console =
    Console.println(RustAudit.renderMinorAudit(Report.readStdin()));
    0

def cmdNixChannelAudit(): Int32 \ {IO, Console, Clock} =
    match Io.readFile("flake.nix") {
        case Err(e) => Console.eprintln(e); 1
        case Ok(content) =>
            let now = Clock.currentTime(TimeUnit.Seconds);
            Console.println(Nix.renderChannelAudit(content, now));
            0
    }

def cmdNixFlakelockAudit(): Int32 \ {IO, Console} =
    finish(forM (
        content <- Io.readFile("flake.lock");
        body    <- Nix.renderFlakelockAudit(content)
    ) yield body)

def cmdElmPagesElmGuard(): Int32 \ {IO, Console} =
    finish(forM (
        raw  <- Io.readFile("app/elm.json");
        body <- ElmPages.renderElmGuard(raw)
    ) yield body)

def cmdElmPagesViteVersion(): Int32 \ {IO, Console} =
    let path = bundledVitePackageJsonPath();
    finish(forM (
        raw <- Io.readFile(path);
        v   <- ElmPages.renderViteVersion(path, raw)
    ) yield v)

def cmdElmPagesCompatKey(): Int32 \ {IO, Console, Env} =
    printCliOutput(ElmPages.renderCompatKeyStandalone(ElmPages.resolveCompatKey()))

def cmdElmPagesAudit(): Int32 \ {IO, Console, Env} =
    let latest = optionFromTrimmed(Report.readStdin());
    match (forM (
        pkgRaw          <- Io.readFile("app/package.json");
        versionSection  <- ElmPages.renderAuditVersionSection(pkgRaw, latest);
        elmJsonRaw      <- Io.readFile("app/elm.json");
        packagesSection <- ElmPages.renderAuditPackagesSection(elmJsonRaw)
    ) yield "${versionSection}\n\n${packagesSection}\n\n--- compatibilityKey ---") {
        case Err(e)   => Console.eprintln(e); 1
        case Ok(body) =>
            Console.println(body);
            printCliOutput(ElmPages.renderCompatKeyForAudit(ElmPages.resolveCompatKey()))
    }

def cmdNpmOutdatedAudit(): Int32 \ {IO, Console} =
    let input = String.trim(Report.readStdin());
    if (input == "") {
        Console.println(Npm.emptyOutdatedReport());
        0
    } else match Npm.renderOutdatedAudit(input) {
        case Err(e) => Console.eprintln(e); 1
        case Ok((report, vite)) =>
            Console.println(report);
            match vite {
                case None => 0
                case Some((current, latest)) =>
                    let bundledMajor = match Io.readFile(bundledVitePackageJsonPath()) {
                        case Ok(raw) => Npm.bundledMajorFromPackageJson(raw)
                        case Err(_)  => "unknown"
                    };
                    Console.println(Npm.renderViteSection(current, latest, bundledMajor));
                    0
            }
    }

def cmdNpmSecurityAudit(): Int32 \ Console =
    let input = String.trim(Report.readStdin());
    if (input == "") {
        Console.println(Npm.emptySecurityReport());
        0
    } else match Npm.renderSecurityAudit(input) {
        case Err(e)   => Console.eprintln(e); 1
        case Ok(body) => Console.println(body); 0
    }

def cmdRustMajorAudit(): Int32 \ {IO, Console} =
    let contents = RustMajor.cargoTomlFiles()
        |> List.filterMap(f -> Io.readFile(f) |> Result.toOption);
    let resolved = RustMajor.parseDeps(contents)
        |> List.map(match (name, constraint) -> (name, constraint, fetchLatestCrate(name)));
    Console.println(RustMajor.renderMajorAudit(resolved));
    0

def cmdNpmPinVersions(): Int32 \ {IO, Console} =
    match (forM (
        lockRaw <- Io.readFile("package-lock.json");
        lock    <- Util.Json.parse(lockRaw) |> Result.mapErr(e -> "package-lock.json: ${e}")
    ) yield lock) {
        case Err(e)   => Console.eprintln(e); 1
        case Ok(lock) => match Result.traverse(pinOneWorkspace(lock), Npm.pinWorkspaces()) {
            case Err(e) => Console.eprintln(e); 1
            case Ok(_)  => 0
        }
    }

/// Read, pin, and write back one workspace's package.json.
def pinOneWorkspace(lock: Util.Json.Json, workspace: (String, String)): Result[String, Unit] \ IO =
    let (file, wsPrefix) = workspace;
    forM (
        raw     <- Io.readFile(file);
        updated <- Npm.pinFile(file, raw, lock, wsPrefix);
        _       <- Io.writeFile(file, updated)
    ) yield ()

def cmdElmVersionsReport(): Int32 \ {IO, Console} =
    let files = "app/elm.json" :: "package/elm.json" :: Nil;
    match Result.traverse(reportOneElmJson, files) {
        case Err(e) => Console.eprintln(e); 1
        case Ok(_)  => 0
    }

/// Read, render, and print one elm.json's version report.
def reportOneElmJson(f: String): Result[String, Unit] \ {IO, Console} =
    forM (
        raw  <- Io.readFile(f);
        body <- Elm.renderVersionsReport(f, raw)
    ) yield {
        Console.println(body);
        Console.println("")
    }

/// The bundled (nested) vite package.json, falling back to the hoisted one.
def bundledVitePackageJsonPath(): String \ IO =
    let candidates = ElmPages.vitePackageJsonCandidates();
    candidates
        |> List.find(p -> Io.exists(p))
        |> Option.getWithDefault(List.last(candidates) |> Option.getWithDefault(""))

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

/// `None` for blank/whitespace-only input, `Some` otherwise — the shape
/// `elm-pages-audit` needs for the "latest version from stdin" argument.
def optionFromTrimmed(s: String): Option[String] =
    let trimmed = String.trim(s);
    if (trimmed == "") None else Some(trimmed)

/// The shared tail of every `read -> render` command: print the body on
/// success, the message on stderr on failure.
def finish(result: Result[String, String]): Int32 \ Console =
    match result {
        case Err(e)    => Console.eprintln(e); 1
        case Ok(body)  => Console.println(body); 0
    }

/// Print a `CliOutput`'s lines to the right stream and return its exit code.
def printCliOutput(out: ElmPages.CliOutput): Int32 \ Console =
    List.forEach(Console.println, out#stdout);
    List.forEach(Console.eprintln, out#stderr);
    out#exitCode

def usage(): Int32 \ Console =
    Console.eprintln("usage: deps-audit <subcommand>");
    Console.eprintln("");
    Console.eprintln("subcommands:");
    Console.eprintln("  npm-security-audit");
    Console.eprintln("  npm-outdated-audit");
    Console.eprintln("  npm-pin-versions");
    Console.eprintln("  elm-versions-report");
    Console.eprintln("  elm-pages-audit");
    Console.eprintln("  elm-pages-compat-key");
    Console.eprintln("  elm-pages-elm-guard");
    Console.eprintln("  elm-pages-vite-version");
    Console.eprintln("  rust-major-audit");
    Console.eprintln("  rust-minor-audit");
    Console.eprintln("  nix-channel-audit");
    Console.eprintln("  nix-flakelock-audit");
    1
