///
/// Shared output formatting for the audit subcommands, matching the
/// section style of the Rust implementation byte for byte.
///
mod DepsAudit.Report {

    use Sys.Console

    /// Render a list as newline-joined lines, or "none" when empty.
    pub def linesOrNone(lines: List[String]): String =
        if (List.isEmpty(lines)) "none" else List.join("\n", lines)

    /// Print a "--- title ---" section followed by its body.
    pub def printSection(title: String, body: String): Unit \ Console =
        Console.println("--- ${title} ---");
        Console.println(body)

    /// Read all of stdin as one string (lines joined with '\n').
    pub def readStdin(): String \ Console =
        def loop(acc) = match Console.readln() {
            case Some(line) => loop(line :: acc)
            case None       => acc
        };
        loop(Nil) |> List.reverse |> List.join("\n")

}
