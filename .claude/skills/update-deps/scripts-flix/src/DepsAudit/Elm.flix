///
/// elm-versions-report: report pinned versions from the elm.json files.
/// Port of scripts/src/elm.rs.
///
mod DepsAudit.Elm {

    use Util.Json.Json
    use Util.Json.Json.{JObject, JString}

    /// Render the report for one elm.json file (path, raw content).
    pub def renderVersionsReport(path: String, raw: String): Result[String, String] =
        match Util.Json.parse(raw) {
            case Err(e)      => Err("${path}: ${e}")
            case Ok(elmJson) =>
                let typeStr = match getKey("type", elmJson) {
                    case Some(JString(t)) => t
                    case _                => "unknown"
                };
                let header = "--- ${path} (${typeStr}) ---";
                let body = match typeStr {
                    case "application" =>
                        let deps = getKey("dependencies", elmJson);
                        let testDeps = getKey("test-dependencies", elmJson);
                        let direct = entries(deps |> Option.flatMap(d -> getKey("direct", d)));
                        let indirect = entries(deps |> Option.flatMap(d -> getKey("indirect", d)));
                        let testDirect = entries(testDeps |> Option.flatMap(d -> getKey("direct", d)));
                        let testIndirect = entries(testDeps |> Option.flatMap(d -> getKey("indirect", d)));
                        let base =
                            ("direct:" :: direct) ::: ("indirect:" :: indirect);
                        let withTest =
                            if (List.isEmpty(testDirect) and List.isEmpty(testIndirect))
                                base
                            else
                                base ::: ("test-direct:" :: testDirect) ::: ("test-indirect:" :: testIndirect);
                        withTest
                    case "package" =>
                        let deps = entries(getKey("dependencies", elmJson));
                        let testDeps = entries(getKey("test-dependencies", elmJson));
                        let base = "dependencies:" :: deps;
                        if (List.isEmpty(testDeps)) base
                        else base ::: ("test-dependencies:" :: testDeps)
                    case _ => Nil
                };
                Ok(List.join("\n", header :: body))
        }

    /// "  name: version" lines for a JSON object of string values,
    /// in sorted key order.
    def entries(obj: Option[Json]): List[String] =
        match obj {
            case Some(JObject(m)) =>
                Map.toList(m) |> List.filterMap(match (name, v) -> match v {
                    case JString(s) => Some("  ${name}: ${s}")
                    case _          => None
                })
            case _ => Nil
        }

    def getKey(key: String, j: Json): Option[Json] = match j {
        case JObject(m) => Map.get(key, m)
        case _          => None
    }

}
