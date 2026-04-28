pub mod Util.Json {

    pub enum JsonValue with ToString {
        case JsonNull
        case JsonBool(Bool)
        case JsonInt(Int32)
        case JsonFloat(Float64)
        case JsonString(String)
        case JsonArray(List[JsonValue])
        case JsonObject(List[(String, JsonValue)])
    }

    pub def render(value: JsonValue): String =
        renderWithIndent(0, value)

    def renderWithIndent(indent: Int32, value: JsonValue): String =
        let spaces = String.repeat(indent, " ");
        let inner = String.repeat(indent + 2, " ");
        match value {
            case JsonValue.JsonNull       => "null"
            case JsonValue.JsonBool(b)    => if (b) "true" else "false"
            case JsonValue.JsonInt(n)     => "${n}"
            case JsonValue.JsonFloat(n)   => "${n}"
            case JsonValue.JsonString(s)  => "\"${escapeString(s)}\""
            case JsonValue.JsonArray(xs)  =>
                if (List.isEmpty(xs))
                    "[]"
                else
                    let items = xs |> List.map(x -> "${inner}${renderWithIndent(indent + 2, x)}");
                    "[\n${List.join(",\n", items)}\n${spaces}]"
            case JsonValue.JsonObject(kvs) =>
                if (List.isEmpty(kvs))
                    "{}"
                else
                    let entries = kvs |> List.map(match (k, v) ->
                        "${inner}\"${escapeString(k)}\": ${renderWithIndent(indent + 2, v)}"
                    );
                    "{\n${List.join(",\n", entries)}\n${spaces}}"
        }

    def escapeString(s: String): String =
        s |> String.replace({src = "\\"}, {dst = "\\\\"})
          |> String.replace({src = "\""}, {dst = "\\\""})
          |> String.replace({src = "\n"}, {dst = "\\n"})
          |> String.replace({src = "\r"}, {dst = "\\r"})
          |> String.replace({src = "\t"}, {dst = "\\t"})

}
