///
/// elm-pages-* subcommands. Port of scripts/src/elm_pages.rs.
///
mod DepsAudit.ElmPages {

    use Sys.Env
    use Util.Json.Json
    use Util.Json.Json.{JObject, JString}
    use DepsAudit.Io

    /// Render the dillonkearns package report from app/elm.json content.
    pub def renderElmGuard(raw: String): Result[String, String] =
        match Util.Json.parse(raw) {
            case Err(e)      => Err("app/elm.json: ${e}")
            case Ok(elmJson) =>
                let deps = getKey("dependencies", elmJson);
                let direct = collectDillonkearns(deps |> Option.flatMap(d -> getKey("direct", d)));
                let indirect = collectDillonkearns(deps |> Option.flatMap(d -> getKey("indirect", d)));
                let header =
                    "--- dillonkearns packages ---" ::
                    List.map(match (n, v) -> "${n}: ${v} (direct)", direct) :::
                    List.map(match (n, v) -> "${n}: ${v} (indirect)", indirect);
                let restore =
                    "" ::
                    "--- restore commands (direct only; indirect restored transitively) ---" ::
                    List.map(match (n, v) -> "elm-json install --yes '${n}@${v}' -- app/elm.json", direct);
                Ok(List.join("\n", header ::: restore))
        }

    /// Extract the version string from a vite package.json.
    pub def renderViteVersion(path: String, raw: String): Result[String, String] =
        match Util.Json.parse(raw) {
            case Err(e)   => Err("${path}: ${e}")
            case Ok(pkg)  => match getKey("version", pkg) {
                case Some(JString(v)) => Ok(v)
                case _                => Err("vite package.json missing version")
            }
        }

    /// The nested-then-hoisted lookup order for elm-pages's bundled vite.
    pub def vitePackageJsonCandidates(): List[String] =
        "node_modules/elm-pages/node_modules/vite/package.json" ::
        "node_modules/vite/package.json" :: Nil

    /// Candidate paths of the CompatibilityKey.elm shipped in the npm
    /// package, in lookup order.
    ///
    /// pnpm installs elm-pages into the `app` workspace, so the repo-root
    /// path only exists in a hoisted layout. The Rust version looked at the
    /// cwd alone and therefore reported "file not found" whenever it was run
    /// from the repository root — which is where the skill runs everything.
    pub def npmKeyFileCandidates(): List[String] =
        "node_modules/elm-pages/src/Pages/Internal/Platform/CompatibilityKey.elm" ::
        "app/node_modules/elm-pages/src/Pages/Internal/Platform/CompatibilityKey.elm" :: Nil

    /// The elm-pages package cache below $HOME.
    pub def cacheDirBelowHome(): String =
        ".elm/0.19.1/packages/dillonkearns/elm-pages"

    /// Parse `currentCompatibilityKey = <n>` out of Elm source.
    pub def parseCompatKey(source: String): Option[Int64] =
        let rgx = regex"currentCompatibilityKey\\s*=\\s*(\\d+)";
        match Regex.capture(rgx, source) {
            case k :: Nil => Int64.fromString(k)
            case _        => None
        }

    /// Standard hint printed when no cached Elm package matches.
    pub def noMatchHint(): String =
        List.join("\n", noMatchHintLines())

    def noMatchHintLines(): List[String] =
        "matchingElmVersion: no-match" ::
        "Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json" :: Nil

    // --- elm-pages-compat-key / the compatibilityKey section of elm-pages-audit ---

    ///
    /// Every state `resolveCompatKey` can end in. Computing this as data —
    /// once — lets the two callers (the standalone subcommand, and the
    /// section embedded in elm-pages-audit) decide how to present the same
    /// outcome without each re-walking the filesystem and re-parsing Elm
    /// source to get there.
    ///
    pub enum CompatKeyOutcome with Eq, ToString {
        case KeyFileNotFound(String)  // the path shown in the "not found" message
        case KeyParseFailed
        case HomeNotSet(Int64)
        case NoMatchingVersion(Int64)
        case MatchFound(Int64, String)
    }

    /// What to print and exit with, split by stream so the caller doesn't
    /// have to know which lines are errors.
    pub type alias CliOutput = {
        stdout = List[String],
        stderr = List[String],
        exitCode = Int32
    }

    /// Locate the npm-shipped CompatibilityKey.elm, parse its key, and (if
    /// possible) search the $HOME Elm package cache for a matching version.
    pub def resolveCompatKey(): CompatKeyOutcome \ {IO, Env} =
        match findNpmKeyFile() {
            case None =>
                let cwd = Env.getProp("user.dir") |> Option.getWithDefault(".");
                let shown = List.head(npmKeyFileCandidates()) |> Option.getWithDefault("");
                CompatKeyOutcome.KeyFileNotFound("${cwd}/${shown}")
            case Some(keyFile) => match Io.readFile(keyFile) |> Result.map(parseCompatKey) {
                case Err(_)       => CompatKeyOutcome.KeyParseFailed
                case Ok(None)     => CompatKeyOutcome.KeyParseFailed
                case Ok(Some(npmKey)) => match Env.getVar("HOME") {
                    case None       => CompatKeyOutcome.HomeNotSet(npmKey)
                    case Some(home) => match findMatchingVersion(home, npmKey) {
                        case Some(v) => CompatKeyOutcome.MatchFound(npmKey, v)
                        case None    => CompatKeyOutcome.NoMatchingVersion(npmKey)
                    }
                }
            }
        }

    /// Render for the standalone `elm-pages-compat-key` subcommand: a
    /// missing key file, a parse failure, or a missing $HOME are hard
    /// failures (stderr, exit 1) — the caller asked specifically for this
    /// value and got nothing usable.
    pub def renderCompatKeyStandalone(outcome: CompatKeyOutcome): CliOutput =
        match outcome {
            case CompatKeyOutcome.KeyFileNotFound(path) =>
                { stdout = Nil, stderr = "${path} not found" :: "Run npm install first." :: Nil, exitCode = 1 }
            case CompatKeyOutcome.KeyParseFailed =>
                { stdout = Nil, stderr = "could not parse compatibilityKey from npm source" :: Nil, exitCode = 1 }
            case CompatKeyOutcome.HomeNotSet(npmKey) =>
                { stdout = "npmKey: ${npmKey}" :: Nil, stderr = "HOME not set" :: Nil, exitCode = 1 }
            case other => commonCompatKeyOutput(other)
        }

    /// Render for the compatibilityKey section of `elm-pages-audit`: never
    /// fails the whole command — every branch is informational stdout,
    /// exit 0. This is the only difference from the standalone renderer.
    pub def renderCompatKeyForAudit(outcome: CompatKeyOutcome): CliOutput =
        match outcome {
            case CompatKeyOutcome.KeyFileNotFound(_) =>
                { stdout = "npmKey: unknown (file not found — run npm install first)" :: Nil, stderr = Nil, exitCode = 0 }
            case CompatKeyOutcome.KeyParseFailed =>
                { stdout = "npmKey: unknown (could not parse)" :: Nil, stderr = Nil, exitCode = 0 }
            case CompatKeyOutcome.HomeNotSet(npmKey) =>
                { stdout = "npmKey: ${npmKey}" :: "matchingElmVersion: unknown (HOME not set)" :: Nil, stderr = Nil, exitCode = 0 }
            case other => commonCompatKeyOutput(other)
        }

    /// The two outcomes both renderers treat identically.
    def commonCompatKeyOutput(outcome: CompatKeyOutcome): CliOutput =
        match outcome {
            case CompatKeyOutcome.NoMatchingVersion(npmKey) =>
                { stdout = "npmKey: ${npmKey}" :: noMatchHintLines(), stderr = Nil, exitCode = 0 }
            case CompatKeyOutcome.MatchFound(npmKey, v) =>
                { stdout = "npmKey: ${npmKey}" :: "matchingElmVersion: ${v}" :: Nil, stderr = Nil, exitCode = 0 }
            case _ =>
                { stdout = Nil, stderr = "unreachable compatibilityKey outcome" :: Nil, exitCode = 1 }
        }

    /// First CompatibilityKey.elm that actually exists, if any.
    def findNpmKeyFile(): Option[String] \ IO =
        npmKeyFileCandidates() |> List.find(p -> Io.exists(p))

    /// Highest cached elm-pages version whose compatibilityKey equals npmKey.
    def findMatchingVersion(home: String, npmKey: Int64): Option[String] \ IO =
        let cacheDir = "${home}/${cacheDirBelowHome()}";
        if (not Io.exists(cacheDir))
            None
        else
            let entries = Io.listDir(cacheDir) |> Result.getWithDefault(Nil);
            entries
                |> List.filter(name -> {
                    let keyFile = "${cacheDir}/${name}/src/Pages/Internal/Platform/CompatibilityKey.elm";
                    if (not Io.exists(keyFile))
                        false
                    else
                        match Io.readFile(keyFile) |> Result.map(parseCompatKey) {
                            case Ok(Some(k)) => k == npmKey
                            case _           => false
                        }
                })
                |> List.sortWith((a, b) -> DepsAudit.Semver.compareSemver(a, b))
                |> List.last

    /// The version header section of elm-pages-audit
    /// (current from app/package.json content, latest from stdin).
    pub def renderAuditVersionSection(pkgRaw: String, latest: Option[String]): Result[String, String] =
        match Util.Json.parse(pkgRaw) {
            case Err(e)  => Err("app/package.json: ${e}")
            case Ok(pkg) =>
                let lookup = key -> getKey(key, pkg) |> Option.flatMap(d -> getKey("elm-pages", d));
                let current = match lookup("dependencies") {
                    case Some(JString(v)) => v
                    case _                => match lookup("devDependencies") {
                        case Some(JString(v)) => v
                        case _                => "unknown"
                    }
                };
                let head = "--- elm-pages version ---" :: "current: ${current}" :: Nil;
                let tail = match latest {
                    case Some(v) =>
                        "latest:  ${v}" ::
                        "status:  ${if (current == v) "up to date" else "update available"}" :: Nil
                    case None => "latest:  unknown (npm view failed)" :: Nil
                };
                Ok(List.join("\n", head ::: tail))
        }

    /// The dillonkearns section of elm-pages-audit (headers differ from elm-guard).
    pub def renderAuditPackagesSection(elmJsonRaw: String): Result[String, String] =
        match Util.Json.parse(elmJsonRaw) {
            case Err(e)      => Err("app/elm.json: ${e}")
            case Ok(elmJson) =>
                let deps = getKey("dependencies", elmJson);
                let direct = collectDillonkearns(deps |> Option.flatMap(d -> getKey("direct", d)));
                let indirect = collectDillonkearns(deps |> Option.flatMap(d -> getKey("indirect", d)));
                Ok(List.join("\n",
                    "--- dillonkearns packages (app/elm.json) ---" ::
                    List.map(match (n, v) -> "${n}: ${v} (direct)", direct) :::
                    List.map(match (n, v) -> "${n}: ${v} (indirect)", indirect) :::
                    "" ::
                    "--- restore commands (for /update-deps elm) ---" ::
                    List.map(match (n, v) -> "elm-json install --yes '${n}@${v}' -- app/elm.json", direct)))
        }

    /// dillonkearns/* entries of a dependency object, in sorted key order.
    pub def collectDillonkearns(obj: Option[Json]): List[(String, String)] =
        match obj {
            case Some(JObject(m)) =>
                Map.toList(m) |> List.filterMap(match (name, v) -> match v {
                    case JString(s) =>
                        if (String.startsWith({prefix = "dillonkearns/"}, name))
                            Some((name, s))
                        else None
                    case _ => None
                })
            case _ => Nil
        }

    pub def getKey(key: String, j: Json): Option[Json] = match j {
        case JObject(m) => Map.get(key, m)
        case _          => None
    }

}
