///
/// elm-pages-* subcommands. Port of scripts/src/elm_pages.rs.
///
/// Sections follow the subcommands: elm-guard, vite lookups, the
/// compatibilityKey resolution/rendering, the elm-pages-audit sections,
/// and finally the dillonkearns helpers shared between them.
///
mod DepsAudit.ElmPages {

    use Sys.Env
    use Util.Json.Json
    use Util.Json.Json.JString
    use DepsAudit.Cli
    use DepsAudit.Io.FileIO
    use DepsAudit.JsonUtil

    // --- elm-pages-elm-guard ---

    /// Render the dillonkearns package report from a parsed elm.json.
    pub def renderElmGuard(elmJson: Json): String =
        let (direct, indirect) = dillonkearnsDeps(elmJson);
        let packages =
            "--- dillonkearns packages ---" :: packageLines(direct, indirect);
        let restore =
            "" ::
            "--- restore commands (direct only; indirect restored transitively) ---" ::
            restoreCommands(direct);
        List.join("\n", packages ::: restore)

    // --- the bundled vite (elm-pages-vite-version, npm-outdated-audit) ---

    /// The nested-then-hoisted lookup order for elm-pages's bundled vite.
    pub def vitePackageJsonCandidates(): List[String] =
        "node_modules/elm-pages/node_modules/vite/package.json" ::
        "node_modules/vite/package.json" :: Nil

    /// The bundled (nested) vite package.json, falling back to the hoisted one.
    pub def bundledVitePackageJsonPath(): String \ FileIO =
        let candidates = vitePackageJsonCandidates();
        candidates
            |> List.find(p -> FileIO.exists(p))
            |> Option.getWithDefault(List.last(candidates) |> Option.getWithDefault(""))

    /// Extract the version string from a parsed vite package.json.
    pub def renderViteVersion(pkg: Json): Result[String, String] =
        JsonUtil.getString("version", pkg)
            |> Option.toOk("vite package.json missing version")

    /// Major component of the bundled vite's version — "unknown" when its
    /// package.json is missing or unparsable.
    pub def bundledViteMajor(): String \ FileIO =
        FileIO.read(bundledVitePackageJsonPath())
            |> Result.map(bundledMajorFromPackageJson)
            |> Result.getWithDefault("unknown")

    /// Major component of a vite package.json's version string.
    pub def bundledMajorFromPackageJson(raw: String): String =
        let major = forM (
            pkg <- Util.Json.parse(raw) |> Result.toOption;
            v   <- JsonUtil.getString("version", pkg);
            m   <- List.head(String.splitOn({substr = "."}, v));
            n   <- Int64.fromString(m)
        ) yield "${n}";
        major |> Option.getWithDefault("unknown")

    // --- elm-pages-compat-key / the compatibilityKey section of elm-pages-audit ---

    ///
    /// Every state `resolveCompatKey` can end in. Computing this as data —
    /// once — lets the two callers (the standalone subcommand, and the
    /// section embedded in elm-pages-audit) decide how to present the same
    /// outcome without each re-walking the filesystem and re-parsing Elm
    /// source to get there.
    ///
    /// `Resolved` carries the cache-search result as `Option[String]`
    /// rather than two more cases: both renderers present a resolved key
    /// identically, so the shared rendering stays a total function.
    pub enum CompatKeyOutcome with Eq, ToString {
        case KeyFileNotFound(String)  // the path shown in the "not found" message
        case KeyParseFailed
        case HomeNotSet(Int64)
        case Resolved(Int64, Option[String])
    }

    /// Locate the npm-shipped CompatibilityKey.elm, parse its key, and (if
    /// possible) search the $HOME Elm package cache for a matching version.
    pub def resolveCompatKey(): CompatKeyOutcome \ {FileIO, Env} =
        resolveCompatKeyAt(Env.getProp("user.dir"), Env.getVar("HOME"))

    /// `resolveCompatKey` with its environment inputs (cwd for the "not
    /// found" message, $HOME) as arguments — the whole lookup then only
    /// needs `FileIO`, so tests can drive it with an in-memory handler.
    pub def resolveCompatKeyAt(cwdOpt: Option[String], homeOpt: Option[String]): CompatKeyOutcome \ FileIO =
        match findNpmKeyFile() {
            case None =>
                let cwd = cwdOpt |> Option.getWithDefault(".");
                let shown = List.head(npmKeyFileCandidates()) |> Option.getWithDefault("");
                CompatKeyOutcome.KeyFileNotFound("${cwd}/${shown}")
            case Some(keyFile) => match FileIO.read(keyFile) |> Result.map(parseCompatKey) {
                case Err(_)       => CompatKeyOutcome.KeyParseFailed
                case Ok(None)     => CompatKeyOutcome.KeyParseFailed
                case Ok(Some(npmKey)) => match homeOpt {
                    case None       => CompatKeyOutcome.HomeNotSet(npmKey)
                    case Some(home) => CompatKeyOutcome.Resolved(npmKey, findMatchingVersion(home, npmKey))
                }
            }
        }

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

    /// First CompatibilityKey.elm that actually exists, if any.
    def findNpmKeyFile(): Option[String] \ FileIO =
        npmKeyFileCandidates() |> List.find(p -> FileIO.exists(p))

    /// Parse `currentCompatibilityKey = <n>` out of Elm source.
    pub def parseCompatKey(source: String): Option[Int64] =
        let rgx = regex"currentCompatibilityKey\\s*=\\s*(\\d+)";
        match Regex.capture(rgx, source) {
            case k :: Nil => Int64.fromString(k)
            case _        => None
        }

    /// The elm-pages package cache below $HOME.
    pub def cacheDirBelowHome(): String =
        ".elm/0.19.1/packages/dillonkearns/elm-pages"

    /// Highest cached elm-pages version whose compatibilityKey equals npmKey.
    def findMatchingVersion(home: String, npmKey: Int64): Option[String] \ FileIO =
        let cacheDir = "${home}/${cacheDirBelowHome()}";
        if (not FileIO.exists(cacheDir))
            None
        else
            let entries = FileIO.list(cacheDir) |> Result.getWithDefault(Nil);
            entries
                |> List.filter(name -> {
                    let keyFile = "${cacheDir}/${name}/src/Pages/Internal/Platform/CompatibilityKey.elm";
                    if (not FileIO.exists(keyFile))
                        false
                    else
                        match FileIO.read(keyFile) |> Result.map(parseCompatKey) {
                            case Ok(Some(k)) => k == npmKey
                            case _           => false
                        }
                })
                |> List.sortBy(DepsAudit.Semver.parse)
                |> List.last

    /// Render for the standalone `elm-pages-compat-key` subcommand: a
    /// missing key file, a parse failure, or a missing $HOME are hard
    /// failures (stderr, exit 1) — the caller asked specifically for this
    /// value and got nothing usable.
    pub def renderCompatKeyStandalone(outcome: CompatKeyOutcome): Cli.Output =
        match outcome {
            case CompatKeyOutcome.KeyFileNotFound(path) =>
                Cli.failLines("${path} not found" :: "Run npm install first." :: Nil)
            case CompatKeyOutcome.KeyParseFailed =>
                Cli.fail("could not parse compatibilityKey from npm source")
            case CompatKeyOutcome.HomeNotSet(npmKey) =>
                Cli.append(Cli.okText("npmKey: ${npmKey}"), Cli.fail("HOME not set"))
            case CompatKeyOutcome.Resolved(npmKey, matched) =>
                resolvedOutput(npmKey, matched)
        }

    /// Render for the compatibilityKey section of `elm-pages-audit`: never
    /// fails the whole command — every branch is informational stdout,
    /// exit 0. This is the only difference from the standalone renderer.
    pub def renderCompatKeyForAudit(outcome: CompatKeyOutcome): Cli.Output =
        match outcome {
            case CompatKeyOutcome.KeyFileNotFound(_) =>
                Cli.okText("npmKey: unknown (file not found — run npm install first)")
            case CompatKeyOutcome.KeyParseFailed =>
                Cli.okText("npmKey: unknown (could not parse)")
            case CompatKeyOutcome.HomeNotSet(npmKey) =>
                Cli.ok("npmKey: ${npmKey}" :: "matchingElmVersion: unknown (HOME not set)" :: Nil)
            case CompatKeyOutcome.Resolved(npmKey, matched) =>
                resolvedOutput(npmKey, matched)
        }

    /// A resolved key renders identically in both modes.
    def resolvedOutput(npmKey: Int64, matched: Option[String]): Cli.Output =
        match matched {
            case None    => Cli.ok("npmKey: ${npmKey}" :: noMatchHintLines())
            case Some(v) => Cli.ok("npmKey: ${npmKey}" :: "matchingElmVersion: ${v}" :: Nil)
        }

    /// Standard hint printed when no cached Elm package matches.
    def noMatchHintLines(): List[String] =
        "matchingElmVersion: no-match" ::
        "Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json" :: Nil

    // --- the other elm-pages-audit sections ---

    /// The version header section of elm-pages-audit
    /// (current from app/package.json content, latest from stdin).
    pub def renderAuditVersionSection(pkg: Json, latest: Option[String]): String =
        let lookup = key -> JsonUtil.getKey(key, pkg)
            |> Option.flatMap(d -> JsonUtil.getString("elm-pages", d));
        let current = lookup("dependencies")
            |> Option.withDefault(default = lookup("devDependencies"))
            |> Option.getWithDefault("unknown");
        let head = "--- elm-pages version ---" :: "current: ${current}" :: Nil;
        let tail = match latest {
            case Some(v) =>
                "latest:  ${v}" ::
                "status:  ${if (current == v) "up to date" else "update available"}" :: Nil
            case None => "latest:  unknown (npm view failed)" :: Nil
        };
        List.join("\n", head ::: tail)

    /// The dillonkearns section of elm-pages-audit (headers differ from elm-guard).
    pub def renderAuditPackagesSection(elmJson: Json): String =
        let (direct, indirect) = dillonkearnsDeps(elmJson);
        List.join("\n",
            "--- dillonkearns packages (app/elm.json) ---" ::
            packageLines(direct, indirect) :::
            "" ::
            "--- restore commands (for /update-deps elm) ---" ::
            restoreCommands(direct))

    // --- dillonkearns helpers shared by elm-guard and elm-pages-audit ---

    /// The (direct, indirect) dillonkearns entries of an application
    /// elm.json's `dependencies` object.
    def dillonkearnsDeps(elmJson: Json): (List[(String, String)], List[(String, String)]) =
        let at = key -> collectDillonkearns(JsonUtil.getAt("dependencies" :: key :: Nil, elmJson));
        (at("direct"), at("indirect"))

    /// dillonkearns/* entries of a dependency object, in sorted key order.
    pub def collectDillonkearns(obj: Option[Json]): List[(String, String)] =
        match obj {
            case Some(Json.JObject(m)) =>
                Map.toList(m) |> List.filterMap(match (name, v) -> match v {
                    case JString(s) =>
                        if (String.startsWith({prefix = "dillonkearns/"}, name))
                            Some((name, s))
                        else None
                    case _ => None
                })
            case _ => Nil
        }

    /// "name: version (direct|indirect)" lines shared by the elm-guard and
    /// elm-pages-audit package sections.
    def packageLines(direct: List[(String, String)], indirect: List[(String, String)]): List[String] =
        List.map(match (n, v) -> "${n}: ${v} (direct)", direct) :::
        List.map(match (n, v) -> "${n}: ${v} (indirect)", indirect)

    /// The elm-json invocations that would restore the given direct pins.
    def restoreCommands(direct: List[(String, String)]): List[String] =
        List.map(match (n, v) -> "elm-json install --yes '${n}@${v}' -- app/elm.json", direct)

}
