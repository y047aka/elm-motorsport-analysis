///
/// Shared report-body formatting: `--- title ---` sections separated by
/// blank lines, with an empty section rendered as `none` rather than left
/// blank. Delivery to the terminal is `DepsAudit.Cli`.
///
mod DepsAudit.Report {

    /// Render a list as newline-joined lines, or "none" when empty.
    pub def linesOrNone(lines: List[String]): String =
        if (List.isEmpty(lines)) "none" else List.join("\n", lines)

    /// Render (title, body) pairs as "--- title ---" sections separated
    /// by blank lines — the shape every audit report is built from.
    pub def sections(xs: List[(String, String)]): String =
        xs
            |> List.map(match (title, body) -> "--- ${title} ---\n${body}")
            |> List.join("\n\n")

}
