///
/// npm-outdated-audit, npm-security-audit and npm-pin-versions.
/// Port of scripts/src/npm.rs.
///
/// Known deviation: the Rust version iterates `vulnerabilities` in
/// document order (serde preserve_order); this port lists them in
/// sorted key order.
///
mod DepsAudit.Npm {

    use Util.Json.Json
    use Util.Json.Json.{JObject, JArray, JString, JBool}
    use DepsAudit.Report

    // --- npm-outdated-audit ---

    pub def emptyOutdatedReport(): String =
        List.join("\n",
            "--- minor updates ---" :: "none" :: "" ::
            "--- major updates ---" :: "none" :: Nil)

    /// Main report (without the vite section). Also returns the vite
    /// entry (current, latest) when present so the caller can append
    /// the filesystem-dependent vite section.
    pub def renderOutdatedAudit(input: String): Result[String, (String, Option[(String, String)])] =
        match Util.Json.parse(input) {
            case Err(e)    => Err("unexpected npm outdated format: ${e}")
            case Ok(data)  =>
                let entries = match data {
                    case JObject(m) => Map.toList(m)
                    case _          => Nil
                };
                let infos = entries |> List.filterMap(match (name, v) ->
                    Option.map(i -> (name, i), parseInfo(v)));
                let minor = infos |> List.filterMap(match (name, i) ->
                    if (i#current != i#wanted)
                        Some("${name}: ${i#current} -> ${i#wanted} (${i#dependent})")
                    else None);
                let major = infos |> List.filterMap(match (name, i) ->
                    if (i#latest != i#wanted)
                        Some("${name}: ${i#current} -> ${i#latest} (${i#dependent})")
                    else None);
                let playwrightChanged = match List.findMap(match (name, i) ->
                    if (name == "@playwright/test") Some(i) else None, infos) {
                    case Some(pw) =>
                        pw#current != pw#wanted or majorOf(pw#latest) > majorOf(pw#current)
                    case None => false
                };
                let vite = List.findMap(match (name, i) ->
                    if (name == "vite") Some((i#current, i#latest)) else None, infos);
                let report = List.join("\n",
                    "--- minor updates ---" ::
                    Report.linesOrNone(minor) ::
                    "" ::
                    "--- major updates ---" ::
                    Report.linesOrNone(major) ::
                    "" ::
                    "--- flags ---" ::
                    "playwright-changed: ${playwrightChanged}" :: Nil);
                Ok((report, vite))
        }

    /// The trailing vite section (bundledMajor is "unknown" when
    /// the bundled package.json is missing or unparsable).
    pub def renderViteSection(current: String, latest: String, bundledMajor: String): String =
        List.join("\n",
            "" ::
            "--- vite ---" ::
            "current: ${current}" ::
            "latest: ${latest}" ::
            "bundled-major: ${bundledMajor}" :: Nil)

    /// Major component of the bundled vite version string.
    pub def bundledMajorFromPackageJson(raw: String): String =
        match Util.Json.parse(raw) {
            case Err(_)  => "unknown"
            case Ok(pkg) => match getKey("version", pkg) {
                case Some(JString(v)) => match List.head(String.splitOn({substr = "."}, v)) {
                    case Some(m) => match Int64.fromString(m) {
                        case Some(n) => "${n}"
                        case None    => "unknown"
                    }
                    case None => "unknown"
                }
                case _ => "unknown"
            }
        }

    type alias OutdatedInfo = {current = String, wanted = String, latest = String, dependent = String}

    def parseInfo(v: Json): Option[OutdatedInfo] =
        forM (
            current <- getString("current", v);
            wanted  <- getString("wanted", v);
            latest  <- getString("latest", v)
        ) yield {
            current = current,
            wanted = wanted,
            latest = latest,
            dependent = getString("dependent", v) |> Option.getWithDefault("")
        }

    def majorOf(version: String): Int64 =
        String.splitOn({substr = "."}, version)
            |> List.head
            |> Option.flatMap(Int64.fromString)
            |> Option.getWithDefault(0i64)

    // --- npm-security-audit ---

    pub def emptySecurityReport(): String =
        List.join("\n",
            "--- vulnerabilities ---" :: "none" :: "" ::
            "--- summary ---" :: "total: 0" :: Nil)

    pub def renderSecurityAudit(input: String): Result[String, String] =
        match Util.Json.parse(input) {
            case Err(e)   => Err("unexpected npm audit format: ${e}")
            case Ok(data) =>
                match getKey("vulnerabilities", data) {
                    case Some(JObject(m)) =>
                        let vulns = Map.toList(m);
                        let results = vulns |> List.map(match (name, info) -> renderVuln(name, info));
                        let lines = results |> List.map(match (line, _) -> line);
                        let fixable = results |> List.count(match (_, kind) -> kind == "fixable");
                        let breaking = results |> List.count(match (_, kind) -> kind == "breaking");
                        Ok(List.join("\n",
                            "--- vulnerabilities ---" ::
                            Report.linesOrNone(lines) ::
                            "" ::
                            "--- summary ---" ::
                            "total: ${List.length(vulns)}" ::
                            "fixable: ${fixable}" ::
                            "fixable-breaking: ${breaking}" :: Nil))
                    case _ => Ok(emptySecurityReport())
                }
        }

    def renderVuln(name: String, info: Json): (String, String) =
        let severity = getString("severity", info) |> Option.getWithDefault("unknown");
        let via = match getKey("via", info) {
            case Some(JArray(xs)) => Vector.toList(xs)
            case _                => Nil
        };
        let titles = via |> List.filterMap(v -> match v {
            case JObject(_) => getString("title", v)
            case _          => None
        });
        let viaNames = via |> List.filterMap(v -> match v {
            case JString(s) => Some(s)
            case _          => None
        });
        let desc = match titles {
            case t :: _ => t
            case Nil    => if (List.isEmpty(viaNames)) "" else "via ${List.join(", ", viaNames)}"
        };
        let (fixStr, fixKind) = match getKey("fixAvailable", info) {
            case Some(JBool(true))  => ("fix available", "fixable")
            case Some(JBool(false)) => ("no fix available", "none")
            case Some(JObject(fa))  =>
                let faName = getString("name", JObject(fa)) |> Option.getWithDefault("");
                let faVersion = getString("version", JObject(fa)) |> Option.getWithDefault("");
                let isMajor = match Map.get("isSemVerMajor", fa) {
                    case Some(JBool(b)) => b
                    case _              => false
                };
                if (isMajor)
                    ("fix: ${faName}@${faVersion} (BREAKING)", "breaking")
                else
                    ("fix: ${faName}@${faVersion}", "fixable")
            case _ => ("no fix available", "none")
        };
        ("${name} (${severity}): ${desc} — ${fixStr}", fixKind)

    // --- npm-pin-versions ---

    /// The workspace package.json files rewritten by npm-pin-versions.
    pub def pinWorkspaces(): List[(String, String)] =
        ("package.json", "") ::
        ("app/package.json", "app") ::
        ("package/package.json", "package") :: Nil

    /// Rewrite one package.json's dependency constraints to the versions
    /// resolved in package-lock.json (or, as a fallback, the constraint
    /// with any ^/~ prefix stripped).
    ///
    /// Unlike the Rust version — which re-serializes the whole document —
    /// this replaces only the version strings in the original text, so
    /// key order and formatting are preserved exactly. It also does not
    /// reproduce a Rust bug where a missing dependencies/devDependencies
    /// key was injected as `"dependencies": null`.
    pub def pinFile(path: String, raw: String, lock: Json, wsPrefix: String): Result[String, String] =
        match Util.Json.parse(raw) {
            case Err(e)  => Err("${path}: ${e}")
            case Ok(pkg) =>
                let pins = ("dependencies" :: "devDependencies" :: Nil)
                    |> List.flatMap(key -> match getKey(key, pkg) {
                        case Some(JObject(m)) =>
                            Map.toList(m) |> List.filterMap(match (name, v) -> match v {
                                case JString(cur) =>
                                    let resolved = match resolveVersion(lock, name, wsPrefix) {
                                        case Some(r) => r
                                        case None    => stripConstraintPrefix(cur)
                                    };
                                    Some((name, cur, resolved))
                                case _ => None
                            })
                        case _ => Nil
                    });
                Ok(List.foldLeft((acc, pin) -> {
                    let (name, cur, resolved) = pin;
                    String.replace(
                        {src = "\"${name}\": \"${cur}\""},
                        {dst = "\"${name}\": \"${resolved}\""},
                        acc)
                }, raw, pins))
        }

    def resolveVersion(lock: Json, name: String, wsPrefix: String): Option[String] =
        let packages = getKey("packages", lock);
        let lookup = key -> packages
            |> Option.flatMap(p -> getKey(key, p))
            |> Option.flatMap(entry -> getString("version", entry));
        let fromWs = if (wsPrefix == "") None else lookup("${wsPrefix}/node_modules/${name}");
        match fromWs {
            case Some(v) => Some(v)
            case None    => lookup("node_modules/${name}")
        }

    def stripConstraintPrefix(constraint: String): String =
        String.dropWhileLeft(c -> c == '^' or c == '~', constraint)

    // --- helpers ---

    def getString(key: String, j: Json): Option[String] =
        match getKey(key, j) {
            case Some(JString(s)) => Some(s)
            case _                => None
        }

    def getKey(key: String, j: Json): Option[Json] = match j {
        case JObject(m) => Map.get(key, m)
        case _          => None
    }

}
