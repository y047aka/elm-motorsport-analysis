/// Rendering that departs from `Util.Json.Encode.render`, which puts every
/// value on a line of its own.
mod Util.Json.Encode.Extra {

    use Util.Json.Encode.JsonValue

    /// Renders as `Util.Json.Encode.render` does, except that an object of at
    /// most two properties, each of whose values fits on a line, is written
    /// inline:
    ///
    ///     { "name": "James CALADO" }
    ///     { "time": "20.708", "elapsed": "20.708" }
    ///
    pub def render(value: JsonValue): String =
        renderWithIndent(0, value)

    def renderWithIndent(indent: Int32, value: JsonValue): String =
        match value {
            case JsonValue.JsonArray(xs)   => renderArray(indent, xs)
            case JsonValue.JsonObject(kvs) => renderObject(indent, kvs)
            case scalar                    => Util.Json.Encode.render(scalar)
        }

    def renderArray(indent: Int32, xs: List[JsonValue]): String =
        if (List.isEmpty(xs))
            "[]"
        else
            onOwnLines(indent, "[", xs |> List.map(x -> renderWithIndent(indent + 2, x)), "]")

    def renderObject(indent: Int32, kvs: List[(String, JsonValue)]): String =
        if (List.isEmpty(kvs))
            "{}"
        else
            let entries = kvs |> List.map(match (k, v) ->
                "${key(k)}: ${renderWithIndent(indent + 2, v)}"
            );
            if (List.length(entries) <= 2 and List.forAll(fitsOnOneLine, entries))
                "{ ${List.join(", ", entries)} }"
            else
                onOwnLines(indent, "{", entries, "}")

    def onOwnLines(indent: Int32, open: String, items: List[String], close: String): String =
        let spaces = String.repeat(indent, " ");
        let inner = String.repeat(indent + 2, " ");
        "${open}\n${inner}${List.join(",\n${inner}", items)}\n${spaces}${close}"

    def fitsOnOneLine(rendered: String): Bool =
        not String.contains({substr = "\n"}, rendered)

    def key(k: String): String =
        Util.Json.Encode.render(JsonValue.JsonString(k))

}
