mod Util.Json {

    pub enum JsonValue with ToString {
        case JsonNull
        case JsonBool(Bool)
        case JsonInt(Int32)
        case JsonFloat(Float64)
        case JsonString(String)
        case JsonArray(List[JsonValue])
        case JsonObject(List[(String, JsonValue)])
    }

    pub def render(value: JsonValue): String = region rc {
        let sb = StringBuilder.empty(rc);
        appendValue!(sb, 0, value);
        StringBuilder.toString(sb)
    }

    def appendValue!(sb: StringBuilder[r], indent: Int32, value: JsonValue): Unit \ r =
        match value {
            case JsonValue.JsonNull       => StringBuilder.appendString!("null", sb)
            case JsonValue.JsonBool(b)    => StringBuilder.appendString!(if (b) "true" else "false", sb)
            case JsonValue.JsonInt(n)     => StringBuilder.appendString!("${n}", sb)
            case JsonValue.JsonFloat(n)   => StringBuilder.appendString!("${n}", sb)
            case JsonValue.JsonString(s)  =>
                StringBuilder.appendString!("\"", sb);
                StringBuilder.appendString!(escapeString(s), sb);
                StringBuilder.appendString!("\"", sb)
            case JsonValue.JsonArray(xs)  =>
                if (List.isEmpty(xs))
                    StringBuilder.appendString!("[]", sb)
                else
                    let spaces = String.repeat(indent, " ");
                    let inner = String.repeat(indent + 2, " ");
                    StringBuilder.appendString!("[\n", sb);
                    appendSeparated!(sb, ",\n", xs, x -> {
                        StringBuilder.appendString!(inner, sb);
                        appendValue!(sb, indent + 2, x)
                    });
                    StringBuilder.appendString!("\n", sb);
                    StringBuilder.appendString!(spaces, sb);
                    StringBuilder.appendString!("]", sb)
            case JsonValue.JsonObject(kvs) =>
                if (List.isEmpty(kvs))
                    StringBuilder.appendString!("{}", sb)
                else
                    let spaces = String.repeat(indent, " ");
                    let inner = String.repeat(indent + 2, " ");
                    StringBuilder.appendString!("{\n", sb);
                    appendSeparated!(sb, ",\n", kvs, match (k, v) -> {
                        StringBuilder.appendString!(inner, sb);
                        StringBuilder.appendString!("\"", sb);
                        StringBuilder.appendString!(escapeString(k), sb);
                        StringBuilder.appendString!("\": ", sb);
                        appendValue!(sb, indent + 2, v)
                    });
                    StringBuilder.appendString!("\n", sb);
                    StringBuilder.appendString!(spaces, sb);
                    StringBuilder.appendString!("}", sb)
        }

    def appendSeparated!(sb: StringBuilder[r], sep: String, xs: List[a], f: a -> Unit \ r): Unit \ r =
        match xs {
            case Nil       => ()
            case x :: Nil  => f(x)
            case x :: rest =>
                f(x);
                StringBuilder.appendString!(sep, sb);
                appendSeparated!(sb, sep, rest, f)
        }

    def escapeString(s: String): String =
        s |> String.replace({src = "\\"}, {dst = "\\\\"})
          |> String.replace({src = "\""}, {dst = "\\\""})
          |> String.replace({src = "\n"}, {dst = "\\n"})
          |> String.replace({src = "\r"}, {dst = "\\r"})
          |> String.replace({src = "\t"}, {dst = "\\t"})

}
