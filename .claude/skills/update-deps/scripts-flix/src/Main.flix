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
/// Flix port of the Rust implementation in ../scripts. Subcommands are
/// added incrementally; unimplemented ones exit with an error so the
/// Rust version remains authoritative until parity is verified.
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
        case "elm-versions-report"    => elmVersionsReport("app/elm.json" :: "package/elm.json" :: Nil)
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
    match Io.readFile("flake.lock") {
        case Err(e) => Console.eprintln(e); 1
        case Ok(content) => match Nix.renderFlakelockAudit(content) {
            case Err(e)   => Console.eprintln(e); 1
            case Ok(body) => Console.println(body); 0
        }
    }

def cmdElmPagesElmGuard(): Int32 \ {IO, Console} =
    match Io.readFile("app/elm.json") {
        case Err(e) => Console.eprintln(e); 1
        case Ok(raw) => match ElmPages.renderElmGuard(raw) {
            case Err(e)   => Console.eprintln(e); 1
            case Ok(body) => Console.println(body); 0
        }
    }

def cmdElmPagesViteVersion(): Int32 \ {IO, Console} =
    let path = bundledVitePackageJsonPath();
    match Io.readFile(path) {
        case Err(e) => Console.eprintln(e); 1
        case Ok(raw) => match ElmPages.renderViteVersion(path, raw) {
            case Err(e)   => Console.eprintln(e); 1
            case Ok(v)    => Console.println(v); 0
        }
    }

def cmdElmPagesCompatKey(): Int32 \ {IO, Console, Env} =
    match findNpmKeyFile() {
        case None =>
            let cwd = Env.getProp("user.dir") |> Option.getWithDefault(".");
            let shown = List.head(ElmPages.npmKeyFileCandidates()) |> Option.getWithDefault("");
            Console.eprintln("${cwd}/${shown} not found");
            Console.eprintln("Run npm install first.");
            1
        case Some(keyFile) =>
            match Io.readFile(keyFile) {
            case Err(e) => Console.eprintln(e); 1
            case Ok(source) => match ElmPages.parseCompatKey(source) {
                case None => Console.eprintln("could not parse compatibilityKey from npm source"); 1
                case Some(npmKey) =>
                    Console.println("npmKey: ${npmKey}");
                    match Env.getVar("HOME") {
                        case None => Console.eprintln("HOME not set"); 1
                        case Some(home) =>
                            Console.println(matchingVersionReport(home, npmKey));
                            0
                    }
            }
        }
    }

def cmdElmPagesAudit(): Int32 \ {IO, Console, Env} =
    let latestRaw = String.trim(Report.readStdin());
    let latest = if (latestRaw == "") None else Some(latestRaw);
    match Io.readFile("app/package.json") {
        case Err(e) => Console.eprintln(e); 1
        case Ok(pkgRaw) => match ElmPages.renderAuditVersionSection(pkgRaw, latest) {
            case Err(e) => Console.eprintln(e); 1
            case Ok(versionSection) => match Io.readFile("app/elm.json") {
                case Err(e) => Console.eprintln(e); 1
                case Ok(elmJsonRaw) => match ElmPages.renderAuditPackagesSection(elmJsonRaw) {
                    case Err(e) => Console.eprintln(e); 1
                    case Ok(packagesSection) =>
                        Console.println(versionSection);
                        Console.println("");
                        Console.println(packagesSection);
                        Console.println("");
                        Console.println("--- compatibilityKey ---");
                        auditCompatKeySection()
                }
            }
        }
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
    match Io.readFile("package-lock.json") {
        case Err(e) => Console.eprintln(e); 1
        case Ok(lockRaw) => match Util.Json.parse(lockRaw) {
            case Err(e)    => Console.eprintln("package-lock.json: ${e}"); 1
            case Ok(lock)  => pinVersions(lock, Npm.pinWorkspaces())
        }
    }

/// The bundled (nested) vite package.json, falling back to the hoisted one.
def bundledVitePackageJsonPath(): String \ IO =
    let candidates = ElmPages.vitePackageJsonCandidates();
    candidates
        |> List.find(p -> Io.exists(p))
        |> Option.getWithDefault(List.last(candidates) |> Option.getWithDefault(""))

/// Rewrite each workspace package.json in turn, stopping at the first error.
def pinVersions(lock: Util.Json.Json, workspaces: List[(String, String)]): Int32 \ {IO, Console} =
    match workspaces {
        case Nil => 0
        case (file, wsPrefix) :: rest => match Io.readFile(file) {
            case Err(e) => Console.eprintln(e); 1
            case Ok(raw) => match Npm.pinFile(file, raw, lock, wsPrefix) {
                case Err(e) => Console.eprintln(e); 1
                case Ok(updated) => match Io.writeFile(file, updated) {
                    case Err(e) => Console.eprintln(e); 1
                    case Ok(_)  => pinVersions(lock, rest)
                }
            }
        }
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

/// First CompatibilityKey.elm that actually exists, if any.
def findNpmKeyFile(): Option[String] \ IO =
    ElmPages.npmKeyFileCandidates() |> List.find(p -> Io.exists(p))

/// The graceful compatibilityKey tail of elm-pages-audit (never fails).
def auditCompatKeySection(): Int32 \ {IO, Console, Env} =
    match findNpmKeyFile() {
        case None =>
            Console.println("npmKey: unknown (file not found — run npm install first)");
            0
        case Some(keyFile) =>
            match Io.readFile(keyFile) |> Result.map(ElmPages.parseCompatKey) {
            case Err(_) => Console.println("npmKey: unknown (could not parse)"); 0
            case Ok(None) => Console.println("npmKey: unknown (could not parse)"); 0
            case Ok(Some(npmKey)) =>
                Console.println("npmKey: ${npmKey}");
                match Env.getVar("HOME") {
                    case None => Console.println("matchingElmVersion: unknown (HOME not set)"); 0
                    case Some(home) =>
                        Console.println(matchingVersionReport(home, npmKey));
                        0
                }
        }
    }

/// "matchingElmVersion: ..." body, searching the $HOME package cache.
def matchingVersionReport(home: String, npmKey: Int64): String \ IO =
    let cacheDir = "${home}/${ElmPages.cacheDirBelowHome()}";
    if (not Io.exists(cacheDir))
        ElmPages.noMatchHint()
    else
        match findMatchingVersion(cacheDir, npmKey) {
            case Some(v) => "matchingElmVersion: ${v}"
            case None    => ElmPages.noMatchHint()
        }

/// Highest cached elm-pages version whose compatibilityKey equals npmKey.
def findMatchingVersion(cacheDir: String, npmKey: Int64): Option[String] \ IO =
    let entries = Io.listDir(cacheDir) |> Result.getWithDefault(Nil);
    let matches = entries |> List.filter(name -> {
        let keyFile = "${cacheDir}/${name}/src/Pages/Internal/Platform/CompatibilityKey.elm";
        if (not Io.exists(keyFile))
            false
        else
            match Io.readFile(keyFile) |> Result.map(ElmPages.parseCompatKey) {
                case Ok(Some(k)) => k == npmKey
                case _           => false
            }
    });
    matches
        |> List.sortWith((a, b) -> DepsAudit.Semver.compareSemver(a, b))
        |> List.last

def elmVersionsReport(files: List[String]): Int32 \ {IO, Console} =
    match files {
        case Nil => 0
        case f :: rest => match Io.readFile(f) {
            case Err(e) => Console.eprintln(e); 1
            case Ok(raw) => match Elm.renderVersionsReport(f, raw) {
                case Err(e)   => Console.eprintln(e); 1
                case Ok(body) =>
                    Console.println(body);
                    Console.println("");
                    elmVersionsReport(rest)
            }
        }
    }

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
