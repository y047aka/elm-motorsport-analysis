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
                let parsed = entries |> List.map(match (name, v) -> (name, parseInfo(v)));
                let bad = parsed |> List.filterMap(match (name, i) ->
                    if (Option.isEmpty(i)) Some(name) else None);
                if (not List.isEmpty(bad))
                    Err("unexpected npm outdated format: missing current/wanted/latest for ${List.join(", ", bad)}")
                else {
                let infos = parsed |> List.filterMap(match (name, i) ->
                    Option.map(x -> (name, x), i));
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
            dependent = dependentOf(v)
        }

    /// The dependent workspace project(s).
    ///
    /// Deviation from the Rust version, which only read the `dependent`
    /// string and therefore always printed an empty `()` with modern pnpm:
    /// pnpm now reports `dependentPackages` (an array of {name, location}).
    def dependentOf(v: Json): String =
        match getString("dependent", v) {
            case Some(d) => d
            case None    => match getKey("dependentPackages", v) {
                case Some(JArray(xs)) =>
                    Vector.toList(xs)
                        |> List.filterMap(p -> getString("name", p))
                        |> List.join(", ")
                case _ => ""
            }
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
    /// Only the version literals inside the `dependencies` and
    /// `devDependencies` objects are rewritten, so key order and formatting
    /// survive untouched and sibling sections (`peerDependencies`,
    /// `overrides`, ...) are left alone. Whitespace around the colon is
    /// irrelevant, and a dependency that cannot be located in the source
    /// text is reported as an error rather than skipped — a partial rewrite
    /// must never look like a success.
    ///
    /// Unlike the Rust version this does not inject `"dependencies": null`
    /// into files that lack the key.
    pub def pinFile(path: String, raw: String, lock: Json, wsPrefix: String): Result[String, String] =
        match Util.Json.parse(raw) {
            case Err(e)  => Err("${path}: ${e}")
            case Ok(pkg) =>
                ("dependencies" :: "devDependencies" :: Nil)
                    |> List.foldLeft((acc, key) ->
                        Result.flatMap(text -> pinSection(path, key, pkg, lock, wsPrefix, text), acc), Ok(raw))
        }

    def pinSection(path: String, key: String, pkg: Json, lock: Json, wsPrefix: String, text: String): Result[String, String] =
        match getKey(key, pkg) {
            case Some(JObject(m)) =>
                let pins = Map.toList(m) |> List.filterMap(match (name, v) -> match v {
                    case JString(cur) =>
                        let resolved = resolveVersion(lock, name, wsPrefix)
                            |> Option.getWithDefault(stripConstraintPrefix(cur));
                        Some((name, cur, resolved))
                    case _ => None
                });
                match objectSpan(key, text) {
                    case None => Err("${path}: could not locate the \"${key}\" object")
                    case Some((s, e)) =>
                        let (rewritten, missing) = applyPins(pins, String.slice(start = s, end = e, text));
                        if (List.isEmpty(missing))
                            Ok(String.sliceLeft(end = s, text) + rewritten + String.sliceRight(start = e, text))
                        else
                            Err("${path}: could not rewrite ${List.join(", ", missing)} in \"${key}\"")
                }
            case _ => Ok(text)
        }

    /// Apply pins to a section's text; also returns the names that could
    /// not be located (so the caller can fail loudly).
    def applyPins(pins: List[(String, String, String)], section: String): (String, List[String]) =
        let (text, missing) = List.foldLeft((acc, pin) -> {
            let (t, ms) = acc;
            let (name, cur, resolved) = pin;
            match findEntryValue(name, t) {
                case None => (t, name :: ms)
                case Some((vs, ve, value)) =>
                    if (value != cur)
                        (t, name :: ms)
                    else if (cur == resolved)
                        (t, ms)
                    else
                        (String.sliceLeft(end = vs, t) + "\"${resolved}\"" + String.sliceRight(start = ve, t), ms)
            }
        }, (section, Nil), pins);
        (text, List.reverse(missing))

    /// Locate `"name" : "value"` (any whitespace around the colon) and
    /// return the span of the quoted value plus its content.
    def findEntryValue(name: String, text: String): Option[(Int32, Int32, String)] =
        let needle = "\"${name}\"";
        let len = String.length(text);
        def afterWs(i) = if (i < len and Char.isWhitespace(String.charAt(i, text))) afterWs(i + 1) else i;
        def closingQuote(j) =
            if (j >= len) None
            else {
                let c = String.charAt(j, text);
                if (c == '\\') closingQuote(j + 2)
                else if (c == '"') Some(j)
                else closingQuote(j + 1)
            };
        def search(fromIdx) =
            match String.indexOfLeftWithOffset({substr = needle}, {offset = fromIdx}, text) {
                case None => None
                case Some(k) =>
                    let colon = afterWs(k + String.length(needle));
                    let vq = if (colon < len and String.charAt(colon, text) == ':') afterWs(colon + 1) else -1;
                    if (vq >= 0 and vq < len and String.charAt(vq, text) == '"')
                        match closingQuote(vq + 1) {
                            case Some(q) => Some((vq, q + 1, String.slice(start = vq + 1, end = q, text)))
                            case None    => None
                        }
                    else
                        search(k + 1)
            };
        search(0)

    /// Span [start, end) of the object literal that follows `"key":`.
    def objectSpan(key: String, text: String): Option[(Int32, Int32)] =
        let len = String.length(text);
        def afterWs(i) = if (i < len and Char.isWhitespace(String.charAt(i, text))) afterWs(i + 1) else i;
        match String.indexOf({substr = "\"${key}\""}, text) {
            case None => None
            case Some(k) =>
                let colon = afterWs(k + String.length(key) + 2);
                if (colon < len and String.charAt(colon, text) == ':') {
                    let open = afterWs(colon + 1);
                    if (open < len and String.charAt(open, text) == '{')
                        matchingBrace(text, open) |> Option.map(close -> (open, close))
                    else
                        None
                } else
                    None
        }

    /// Index just past the `}` matching the `{` at `openIdx`, skipping
    /// braces that appear inside string literals.
    def matchingBrace(text: String, openIdx: Int32): Option[Int32] =
        let len = String.length(text);
        def loop(i, depth, inStr, esc) =
            if (i >= len) None
            else {
                let c = String.charAt(i, text);
                if (inStr) {
                    if (esc) loop(i + 1, depth, true, false)
                    else if (c == '\\') loop(i + 1, depth, true, true)
                    else if (c == '"') loop(i + 1, depth, false, false)
                    else loop(i + 1, depth, true, false)
                } else if (c == '"')
                    loop(i + 1, depth, true, false)
                else if (c == '{')
                    loop(i + 1, depth + 1, false, false)
                else if (c == '}')
                    (if (depth == 1) Some(i + 1) else loop(i + 1, depth - 1, false, false))
                else
                    loop(i + 1, depth, false, false)
            };
        loop(openIdx, 0, false, false)

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
