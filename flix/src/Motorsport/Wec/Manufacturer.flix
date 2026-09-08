/// How the timing feed spells a manufacturer's name where it spells one two
/// ways. Every name not here is its own.
///
/// Which manufacturers there are is the feed's to say and the app's to colour;
/// what is here is only the knowledge that two of its spellings are one
/// manufacturer, which no reading of the files recovers.
mod Motorsport.Wec.Manufacturer {

    /// 2026's Le Mans file writes `Mercedes-AMG` where the season's other
    /// rounds write `Mercedes`.
    pub def aliases(): List[(String, String)] =
        ("Mercedes-AMG", "Mercedes") :: Nil

    pub def canonicalOf(spelling: String): String =
        aliases()
            |> List.find(match (written, _) -> written == spelling)
            |> Option.map(match (_, canonical) -> canonical)
            |> Option.getWithDefault(spelling)

}
