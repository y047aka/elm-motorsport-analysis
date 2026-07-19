///
/// Small JSON accessors shared by every subcommand module.
///
/// `Util.Json.FromJson` offers key lookups too, but its accessors fail on
/// non-objects; the audits want the quieter "absent" (`None`) for any
/// shape mismatch, so these are defined once here instead of per module.
///
mod DepsAudit.JsonUtil {

    use Util.Json.Json
    use Util.Json.Json.{JObject, JString}

    /// Parse `raw`, labelling failures "<label>: <error>".
    pub def parseDoc(label: String, raw: String): Result[String, Json] =
        Util.Json.parse(raw) |> Result.mapErr(e -> "${label}: ${e}")

    /// The value at `key`, when `j` is an object that has it.
    pub def getKey(key: String, j: Json): Option[Json] = match j {
        case JObject(m) => Map.get(key, m)
        case _          => None
    }

    /// The value reached by following `path` key by key — the counterpart
    /// of optional chaining (`j?.a?.b`) in the TypeScript predecessor.
    pub def getAt(path: List[String], j: Json): Option[Json] =
        List.foldLeft((acc, key) -> Option.flatMap(getKey(key), acc), Some(j), path)

    /// The string at `key`, when `j` is an object holding a string there.
    pub def getString(key: String, j: Json): Option[String] =
        match getKey(key, j) {
            case Some(JString(s)) => Some(s)
            case _                => None
        }

}
