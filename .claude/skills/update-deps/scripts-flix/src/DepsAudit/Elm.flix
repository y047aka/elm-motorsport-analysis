///
/// elm-versions-report: report pinned versions from the elm.json files.
///
mod DepsAudit.Elm {

    use Util.Json.Json
    use Util.Json.Json.{JObject, JString}
    use DepsAudit.JsonUtil

    /// Render the report for one parsed elm.json (path appears in the header).
    pub def renderVersionsReport(path: String, elmJson: Json): String =
        let typeStr = JsonUtil.getString("type", elmJson) |> Option.getWithDefault("unknown");
        let header = "--- ${path} (${typeStr}) ---";
        let body = match typeStr {
            case "application" => applicationBody(elmJson)
            case "package"     => packageBody(elmJson)
            case _             => Nil
        };
        List.join("\n", header :: body)

    def applicationBody(elmJson: Json): List[String] =
        let at = path -> entryLines(JsonUtil.getAt(path, elmJson));
        let direct = at("dependencies" :: "direct" :: Nil);
        let indirect = at("dependencies" :: "indirect" :: Nil);
        let testDirect = at("test-dependencies" :: "direct" :: Nil);
        let testIndirect = at("test-dependencies" :: "indirect" :: Nil);
        let base = ("direct:" :: direct) ::: ("indirect:" :: indirect);
        if (List.isEmpty(testDirect) and List.isEmpty(testIndirect))
            base
        else
            base ::: ("test-direct:" :: testDirect) ::: ("test-indirect:" :: testIndirect)

    def packageBody(elmJson: Json): List[String] =
        let deps = entryLines(JsonUtil.getKey("dependencies", elmJson));
        let testDeps = entryLines(JsonUtil.getKey("test-dependencies", elmJson));
        let base = "dependencies:" :: deps;
        if (List.isEmpty(testDeps)) base
        else base ::: ("test-dependencies:" :: testDeps)

    /// "  name: version" lines for a JSON object of string values,
    /// in sorted key order.
    def entryLines(obj: Option[Json]): List[String] =
        match obj {
            case Some(JObject(m)) =>
                Map.toList(m) |> List.filterMap(match (name, v) -> match v {
                    case JString(s) => Some("  ${name}: ${s}")
                    case _          => None
                })
            case _ => Nil
        }

}
