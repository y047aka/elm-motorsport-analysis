use Sys.Console
use Sys.Env
use Sys.Exit
use Time.Clock
use Time.TimeUnit

use DepsAudit.Cli
use DepsAudit.Crates
use DepsAudit.Crates.CrateRegistry
use DepsAudit.Elm
use DepsAudit.Io
use DepsAudit.Io.FileIO
use DepsAudit.JsonUtil
use DepsAudit.Nix
use DepsAudit.Npm
use DepsAudit.RustAudit
use DepsAudit.RustMajor

///
/// deps-audit: audit helpers for the update-deps skill.
///
/// Every subcommand is a `Cli.Output`-returning function: it computes what
/// belongs on stdout, on stderr, and in the exit code, and returns that as
/// data. `main` performs the single `Cli.emit` that touches the terminal,
/// and installs the real handlers for the two abstract effects — `FileIO`
/// (the filesystem) and `CrateRegistry` (crates.io) — so below `main` a
/// test can run any subcommand against in-memory substitutes.
///
/// This file owns the input paths and only wires modules together; paths
/// whose structure is itself domain knowledge (candidate orders,
/// pin targets) stay in their modules. Syntactic parsing
/// (`JsonUtil.parseDoc`) also happens here — each read names its path
/// once, for both the `FileIO.read` and the parse-error label — so a
/// subcommand reads as read -> parse -> render, and most module renderers
/// are total `Json -> String` functions; only semantic validation (a
/// required key missing, a malformed entry) stays in the modules as
/// `Result`. Fallible steps chain with `forM`/`yield` over
/// `Result[String, _]`, so the steps read top-to-bottom in the order they
/// run, with failure handled once at the boundary rather than at each
/// step.
///
def main(): Unit \ {Env, IO, Exit, Console, Clock} =
    Exit.exit(Cli.emit(Io.runWithIO(() -> Crates.runWithIO(() -> route(Env.getArgs())))))

def route(args: List[String]): Cli.Output \ {FileIO, CrateRegistry, Console, Clock} =
    match args {
        case cmd :: Nil => dispatch(cmd)
        case _          => usage()
    }

def dispatch(cmd: String): Cli.Output \ {FileIO, CrateRegistry, Console, Clock} =
    match cmd {
        case "rust-minor-audit"       => cmdRustMinorAudit()
        case "nix-channel-audit"      => cmdNixChannelAudit()
        case "nix-flakelock-audit"    => cmdNixFlakelockAudit()
        case "elm-versions-report"    => cmdElmVersionsReport()
        case "npm-outdated-audit"     => cmdNpmOutdatedAudit()
        case "npm-security-audit"     => cmdNpmSecurityAudit()
        case "rust-major-audit"       => cmdRustMajorAudit()
        case "npm-pin-versions"       => cmdNpmPinVersions()
        case _                        => usage()
    }

// --- nix ---

def cmdNixChannelAudit(): Cli.Output \ {FileIO, Clock} =
    let now = Clock.currentTime(TimeUnit.Seconds);
    Cli.fromResult(forM (
        content <- FileIO.read("flake.nix")
    ) yield Nix.renderChannelAudit(content, now))

def cmdNixFlakelockAudit(): Cli.Output \ FileIO =
    Cli.fromResult(forM (
        raw  <- FileIO.read("flake.lock");
        lock <- JsonUtil.parseDoc("unexpected flake.lock format", raw)
    ) yield Nix.renderFlakelockAudit(lock))

// --- elm ---

def cmdElmVersionsReport(): Cli.Output \ FileIO =
    Cli.traverseUntilFailure(reportOneElmJson, "app/elm.json" :: "package/elm.json" :: Nil)

/// One elm.json's section, followed by the blank line that separates files.
def reportOneElmJson(f: String): Cli.Output \ FileIO =
    Cli.fromResultWith(body -> Cli.ok(body :: "" :: Nil), forM (
        raw     <- FileIO.read(f);
        elmJson <- JsonUtil.parseDoc(f, raw)
    ) yield Elm.renderVersionsReport(f, elmJson))

// --- npm ---

def cmdNpmOutdatedAudit(): Cli.Output \ Console =
    let input = String.trim(Cli.readStdin());
    if (input == "")
        Cli.okText(Npm.emptyOutdatedReport())
    else
        Cli.fromResult(forM (
            data <- JsonUtil.parseDoc("unexpected npm outdated format", input);
            r    <- Npm.renderOutdatedAudit(data)
        ) yield r)

def cmdNpmSecurityAudit(): Cli.Output \ Console =
    let input = String.trim(Cli.readStdin());
    if (input == "")
        Cli.okText(Npm.emptySecurityReport())
    else
        Cli.fromResult(forM (
            data <- JsonUtil.parseDoc("unexpected npm audit format", input)
        ) yield Npm.renderSecurityAudit(data))

def cmdNpmPinVersions(): Cli.Output \ FileIO =
    let lockPath = "package-lock.json";
    Cli.fromResultWith(lock -> Cli.traverseUntilFailure(pinOneTarget(lock), Npm.pinTargets()), forM (
        lockRaw <- FileIO.read(lockPath);
        lock    <- JsonUtil.parseDoc(lockPath, lockRaw)
    ) yield lock)

/// Read, pin, and write back one package.json. Prints nothing on success —
/// the rewritten file is the result.
def pinOneTarget(lock: Util.Json.Json, target: (String, String)): Cli.Output \ FileIO =
    let (file, wsPrefix) = target;
    Cli.fromResultWith(_ -> Cli.empty(), forM (
        raw     <- FileIO.read(file);
        pkg     <- JsonUtil.parseDoc(file, raw);
        updated <- Npm.pinFile(file, raw, pkg, lock, wsPrefix);
        _       <- FileIO.write({str = updated}, file)
    ) yield ())

// --- rust ---

def cmdRustMinorAudit(): Cli.Output \ Console =
    Cli.okText(RustAudit.renderMinorAudit(Cli.readStdin()))

def cmdRustMajorAudit(): Cli.Output \ {FileIO, CrateRegistry} =
    let contents = RustMajor.cargoTomlFiles()
        |> List.filterMap(f -> FileIO.read(f) |> Result.toOption);
    let resolved = RustMajor.parseDeps(contents)
        |> List.map(match (name, constraint) -> (name, constraint, CrateRegistry.latest(name)));
    Cli.okText(RustMajor.renderMajorAudit(resolved))

// --- shared helpers ---

def usage(): Cli.Output =
    Cli.failLines(
        "usage: deps-audit <subcommand>" ::
        "" ::
        "subcommands:" ::
        "  npm-security-audit" ::
        "  npm-outdated-audit" ::
        "  npm-pin-versions" ::
        "  elm-versions-report" ::
        "  rust-major-audit" ::
        "  rust-minor-audit" ::
        "  nix-channel-audit" ::
        "  nix-flakelock-audit" :: Nil)
