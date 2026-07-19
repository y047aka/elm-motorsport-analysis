use Sys.Console
use Sys.Env
use Sys.Exit
use Time.Clock
use Time.TimeUnit

use DepsAudit.Cli
use DepsAudit.Crates
use DepsAudit.Crates.CrateRegistry
use DepsAudit.Elm
use DepsAudit.ElmPages
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
/// workspace pairs) stay in their modules. Syntactic parsing
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

def route(args: List[String]): Cli.Output \ {FileIO, CrateRegistry, Console, Clock, Env} =
    match args {
        case cmd :: Nil => dispatch(cmd)
        case _          => usage()
    }

def dispatch(cmd: String): Cli.Output \ {FileIO, CrateRegistry, Console, Clock, Env} =
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

// --- elm-pages ---

def cmdElmPagesElmGuard(): Cli.Output \ FileIO =
    let path = "app/elm.json";
    Cli.fromResult(forM (
        raw     <- FileIO.read(path);
        elmJson <- JsonUtil.parseDoc(path, raw)
    ) yield ElmPages.renderElmGuard(elmJson))

def cmdElmPagesViteVersion(): Cli.Output \ FileIO =
    let path = ElmPages.bundledVitePackageJsonPath();
    Cli.fromResult(forM (
        raw     <- FileIO.read(path);
        pkg     <- JsonUtil.parseDoc(path, raw);
        version <- ElmPages.renderViteVersion(pkg)
    ) yield version)

def cmdElmPagesCompatKey(): Cli.Output \ {FileIO, Env} =
    ElmPages.renderCompatKeyStandalone(ElmPages.resolveCompatKey())

def cmdElmPagesAudit(): Cli.Output \ {FileIO, Console, Env} =
    let latest = optionFromTrimmed(Cli.readStdin());
    let pkgPath = "app/package.json";
    let elmJsonPath = "app/elm.json";
    Cli.fromResult(forM (
        pkgRaw     <- FileIO.read(pkgPath);
        pkg        <- JsonUtil.parseDoc(pkgPath, pkgRaw);
        elmJsonRaw <- FileIO.read(elmJsonPath);
        elmJson    <- JsonUtil.parseDoc(elmJsonPath, elmJsonRaw)
    ) yield {
        let versionSection = ElmPages.renderAuditVersionSection(pkg, latest);
        let packagesSection = ElmPages.renderAuditPackagesSection(elmJson);
        "${versionSection}\n\n${packagesSection}\n\n--- compatibilityKey ---"
    })
        |> Cli.andThen(() -> ElmPages.renderCompatKeyForAudit(ElmPages.resolveCompatKey()))

// --- npm ---

def cmdNpmOutdatedAudit(): Cli.Output \ {FileIO, Console} =
    let input = String.trim(Cli.readStdin());
    if (input == "")
        Cli.okText(Npm.emptyOutdatedReport())
    else
        Cli.fromResultWith(match (report, vite) ->
            Cli.okText(report) |> Cli.andThen(() -> viteSection(vite)),
            forM (
                data <- JsonUtil.parseDoc("unexpected npm outdated format", input);
                r    <- Npm.renderOutdatedAudit(data)
            ) yield r)

/// The trailing vite section, present when npm outdated reported a vite
/// entry. The bundled major comes off disk via `ElmPages.bundledViteMajor`.
def viteSection(vite: Option[(String, String)]): Cli.Output \ FileIO =
    match vite {
        case None => Cli.empty()
        case Some((current, latest)) =>
            Cli.okText(Npm.renderViteSection(current, latest, ElmPages.bundledViteMajor()))
    }

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
    Cli.fromResultWith(lock -> Cli.traverseUntilFailure(pinOneWorkspace(lock), Npm.pinWorkspaces()), forM (
        lockRaw <- FileIO.read(lockPath);
        lock    <- JsonUtil.parseDoc(lockPath, lockRaw)
    ) yield lock)

/// Read, pin, and write back one workspace's package.json. Prints nothing
/// on success — the rewritten file is the result.
def pinOneWorkspace(lock: Util.Json.Json, workspace: (String, String)): Cli.Output \ FileIO =
    let (file, wsPrefix) = workspace;
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

/// `None` for blank/whitespace-only input, `Some` otherwise — the shape
/// `elm-pages-audit` needs for the "latest version from stdin" argument.
def optionFromTrimmed(s: String): Option[String] =
    let trimmed = String.trim(s);
    if (trimmed == "") None else Some(trimmed)

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
