///
/// elm-pages-* subcommands. Port of scripts/src/elm_pages.rs.
/// (elm-pages-audit and elm-pages-compat-key follow in a later step.)
///
mod DepsAudit.ElmPages {

    use Util.Json.Json
    use Util.Json.Json.{JObject, JString}

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
        "matchingElmVersion: no-match" + "\n" +
        "Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json"

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
