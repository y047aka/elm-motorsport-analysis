/// Rendering that departs from `Util.Json.Encode.render`, which puts every
/// value on a line of its own.
mod Util.Json.Encode.Extra {

    use Util.Json.Encode.JsonValue

    /// Renders as `Util.Json.Encode.render` does, except that an object holding
    /// a single property whose value fits on a line is written inline:
    ///
    ///     { "name": "James CALADO" }
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
            let spaces = String.repeat(indent, " ");
            let inner = String.repeat(indent + 2, " ");
            let items = xs |> List.map(x -> "${inner}${renderWithIndent(indent + 2, x)}");
            "[\n${List.join(",\n", items)}\n${spaces}]"

    def renderObject(indent: Int32, kvs: List[(String, JsonValue)]): String =
        match kvs {
            case Nil           => "{}"
            case (k, v) :: Nil =>
                let rendered = renderWithIndent(indent + 2, v);
                if (fitsOnOneLine(rendered))
                    "{ ${key(k)}: ${rendered} }"
                else
                    renderProperties(indent, kvs)
            case _             => renderProperties(indent, kvs)
        }

    def renderProperties(indent: Int32, kvs: List[(String, JsonValue)]): String =
        let spaces = String.repeat(indent, " ");
        let inner = String.repeat(indent + 2, " ");
        let entries = kvs |> List.map(match (k, v) ->
            "${inner}${key(k)}: ${renderWithIndent(indent + 2, v)}"
        );
        "{\n${List.join(",\n", entries)}\n${spaces}}"

    def fitsOnOneLine(rendered: String): Bool =
        not String.contains({substr = "\n"}, rendered)

    def key(k: String): String =
        Util.Json.Encode.render(JsonValue.JsonString(k))

}
