///
/// npm-outdated-audit and npm-security-audit.
/// Port of scripts/src/npm.rs.
///
/// Known deviation: the Rust version iterates `vulnerabilities` in
/// document order (serde preserve_order); this port lists them in
/// sorted key order.
///
mod DepsAudit.Npm {

    use Util.Json.Json
    use Util.Json.Json.{JObject, JArray, JString, JBool}
    use DepsAudit.JsonUtil
    use DepsAudit.Report

    // --- npm-outdated-audit ---

    pub def emptyOutdatedReport(): String =
        Report.sections(
            ("minor updates", "none") ::
            ("major updates", "none") :: Nil)

    /// Report from the parsed outdated document.
    pub def renderOutdatedAudit(data: Json): Result[String, String] =
        forM (
            infos <- parseInfos(data)
        ) yield {
            let minor = infos |> List.filterMap(match (name, i) ->
                if (i#current != i#wanted)
                    Some("${name}: ${i#current} -> ${i#wanted}")
                else None);
            // `latest != wanted`, not a numeric comparison: an earlier
            // TypeScript predecessor used `parseInt(latest) > parseInt(current)`,
            // which silently dropped same-major bumps (e.g. 2.4.9 -> 2.4.10)
            // from this section. Keep this as `!=`.
            let major = infos |> List.filterMap(match (name, i) ->
                if (i#latest != i#wanted)
                    Some("${name}: ${i#current} -> ${i#latest}")
                else None);
            let playwrightChanged = match List.findMap(match (name, i) ->
                if (name == "@playwright/test") Some(i) else None, infos) {
                case Some(pw) =>
                    pw#current != pw#wanted or majorOf(pw#latest) > majorOf(pw#current)
                case None => false
            };
            Report.sections(
                ("minor updates", Report.linesOrNone(minor)) ::
                ("major updates", Report.linesOrNone(major)) ::
                ("flags", "playwright-changed: ${playwrightChanged}") :: Nil)
        }

    type alias OutdatedInfo = {current = String, wanted = String, latest = String}

    /// The (name, info) entries of the outdated document, failing when any
    /// entry lacks current/wanted/latest. All malformed entries are named
    /// in the error, not just the first — hence the partition rather than
    /// a short-circuiting traverse.
    def parseInfos(data: Json): Result[String, List[(String, OutdatedInfo)]] =
        let entries = match data {
            case JObject(m) => Map.toList(m)
            case _          => Nil
        };
        let (good, bad) = entries
            |> List.map(match (name, v) -> (name, parseInfo(v)))
            |> List.partition(match (_, i) -> not Option.isEmpty(i));
        if (not List.isEmpty(bad))
            Err("unexpected npm outdated format: missing current/wanted/latest for ${List.join(", ", List.map(fst, bad))}")
        else
            Ok(good |> List.filterMap(match (name, i) -> Option.map(x -> (name, x), i)))

    def parseInfo(v: Json): Option[OutdatedInfo] =
        forM (
            current <- JsonUtil.getString("current", v);
            wanted  <- JsonUtil.getString("wanted", v);
            latest  <- JsonUtil.getString("latest", v)
        ) yield {
            current = current,
            wanted = wanted,
            latest = latest
        }

    def majorOf(version: String): Int64 =
        String.splitOn({substr = "."}, version)
            |> List.head
            |> Option.flatMap(Int64.fromString)
            |> Option.getWithDefault(0i64)

    // --- npm-security-audit ---

    pub def emptySecurityReport(): String =
        Report.sections(
            ("vulnerabilities", "none") ::
            ("summary", "total: 0") :: Nil)

    /// How a vulnerability can be fixed, per npm audit's `fixAvailable`.
    enum FixKind with Eq {
        case Fixable
        case Breaking
        case NoFix
    }

    /// Render the report from the parsed audit document.
    pub def renderSecurityAudit(data: Json): String =
        match JsonUtil.getKey("vulnerabilities", data) {
            case Some(JObject(m)) =>
                let vulns = Map.toList(m);
                let results = vulns |> List.map(match (name, info) -> renderVuln(name, info));
                let lines = results |> List.map(match (line, _) -> line);
                let fixable = results |> List.count(match (_, kind) -> kind == FixKind.Fixable);
                let breaking = results |> List.count(match (_, kind) -> kind == FixKind.Breaking);
                Report.sections(
                    ("vulnerabilities", Report.linesOrNone(lines)) ::
                    ("summary", "total: ${List.length(vulns)}\nfixable: ${fixable}\nfixable-breaking: ${breaking}") :: Nil)
            case _ => emptySecurityReport()
        }

    def renderVuln(name: String, info: Json): (String, FixKind) =
        let severity = JsonUtil.getString("severity", info) |> Option.getWithDefault("unknown");
        let via = match JsonUtil.getKey("via", info) {
            case Some(JArray(xs)) => Vector.toList(xs)
            case _                => Nil
        };
        let titles = via |> List.filterMap(v -> match v {
            case JObject(_) => JsonUtil.getString("title", v)
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
        let (fixStr, fixKind) = match JsonUtil.getKey("fixAvailable", info) {
            case Some(JBool(true))  => ("fix available", FixKind.Fixable)
            case Some(JBool(false)) => ("no fix available", FixKind.NoFix)
            case Some(JObject(fa))  =>
                let faName = JsonUtil.getString("name", JObject(fa)) |> Option.getWithDefault("");
                let faVersion = JsonUtil.getString("version", JObject(fa)) |> Option.getWithDefault("");
                let isMajor = match Map.get("isSemVerMajor", fa) {
                    case Some(JBool(b)) => b
                    case _              => false
                };
                if (isMajor)
                    ("fix: ${faName}@${faVersion} (BREAKING)", FixKind.Breaking)
                else
                    ("fix: ${faName}@${faVersion}", FixKind.Fixable)
            case _ => ("no fix available", FixKind.NoFix)
        };
        ("${name} (${severity}): ${desc} — ${fixStr}", fixKind)

}
