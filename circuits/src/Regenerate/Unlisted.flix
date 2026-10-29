/// Kept files that answer to no config — the counterpart to the CLI's
/// `Cli.Load.Unlisted`, which reports CSVs no calendar entry names. A circuit's
/// word misspelled keeps its answer out of every fence quietly: the fence walks
/// the configs, and a directory no config names is walked past.
pub mod Regenerate.Unlisted {

    use Circuit.Circuit

    /// The names `found` that `claimed` answers to none of.
    pub def detect(claimed: List[String], found: List[String]): List[String] =
        found |> List.filter(name -> not List.memberOf(name, claimed))

    /// The words the configs are authored for — the words that name a circuit's
    /// directory, its kept answer and the file the app reads.
    pub def words(circuits: List[Circuit]): List[String] =
        List.map(circuit -> circuit#word, circuits)

    /// The geometry files the app is served, by name.
    pub def drawn(circuits: List[Circuit]): List[String] =
        List.map(circuit -> Circuit.lastPart(circuit#file), circuits)
}
