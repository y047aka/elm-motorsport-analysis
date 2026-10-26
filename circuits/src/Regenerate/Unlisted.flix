/// Kept files that answer to no config — the counterpart to the CLI's
/// `Cli.Load.Unlisted`, which reports CSVs no calendar entry names. A circuit's
/// word misspelled keeps its answer out of every fence quietly: the fence walks
/// the configs, and a directory no config names is walked past. Kept apart from
/// the walk that finds them because this is the half that can be wrong
/// unnoticed — the fence still answers for every circuit it knows, and only
/// these warnings are about what it does not.
pub mod Regenerate.Unlisted {

    use Circuit.Circuit

    /// The files that say a directory was made to keep evidence: one of them in
    /// a directory whose name no circuit is authored for is a word misspelled.
    pub def evidence(): List[String] =
        "overpass.json" :: "atlas.geojson" :: Nil

    /// The names `found` that `claimed` answers to none of.
    pub def detect(claimed: List[String], found: List[String]): List[String] =
        found |> List.filter(name -> not List.memberOf(name, claimed))

    /// The words the configs are authored for — the words that name a circuit's
    /// directory, its kept answer and the file the app reads.
    pub def words(circuits: List[Circuit]): List[String] =
        List.map(circuit -> circuit#word, circuits)

    /// The geometry files the app is served, by name.
    pub def drawn(circuits: List[Circuit]): List[String] =
        List.map(circuit -> lastPart(circuit#file), circuits)

    /// A path's last part. The two sides being compared are spelled by different
    /// means — one authored as a full path in the config, the other read off a
    /// directory — so everything above the file's own name is dropped rather than
    /// trusted to match.
    def lastPart(path: String): String =
        match String.splitOn({substr = "/"}, path) |> List.filter(part -> part != "") {
            case Nil    => ""
            case parts  => Option.getWithDefault("", List.last(parts))
        }
}
