/// The questions this project asks OpenStreetMap, spelled once each.
///
/// Three are asked, and each is the shortest answer its reader can work with:
///
///   * `survey` is the one a geometry is drawn from: the relation, then the ways that
///     hold its line with their tags, then the nodes those ways name.
///   * `candidates` is the one asked before a circuit has a config: every relation a box
///     holds that is tagged as a circuit, a motor-sport route or a raceway, with its tags
///     and nothing else. Which of them is the circuit is the next question's answer.
///   * `ways` is the one that decides it: the relation whole and its ways with their
///     geometry, which is the only answer a role's length can be measured out of.
///
/// Both questions that walk a relation recurse through `way(r)` — the difference between
/// drawing a lap and lengthening one is that only the survey then asks the nodes
/// themselves, which is a chain's work and not a measurement's.
///
/// An extent is `south,west,north,east`, which is what Overpass takes and what the probe
/// echoes back so that a reader can tell what was asked of the ground.
pub mod Overpass.Query {

    /// The question one circuit's survey is answered with. `out body` is the one spelling
    /// that carries a way's node refs and a node's degrees at once, which is what
    /// `Survey` chains a lap out of; `out skel` is enough of a node to chain from.
    pub def survey(relation: Int64): String =
        "[out:json][timeout:120];relation(${relation});out body;way(r);out body;node(w);out skel;"

    /// Every relation a box holds that could be a circuit, tags only. A road tagged as a
    /// route catches the box too, so the tags are what the reader picks from.
    pub def candidates(extent: String): String =
        let selectors =
            "relation[\"type\"=\"circuit\"](${extent});" ::
            "relation[\"sport\"~\"^motor\"](${extent});" ::
            "relation[\"motorsport\"](${extent});" ::
            "relation[\"route\"~\"^(raceway|motorsport|racing)$\"](${extent});" ::
            "relation[\"highway\"=\"raceway\"](${extent});" :: Nil;
        "[out:json][timeout:90];(${String.intercalate("", selectors)});out tags;"

    /// The relation whole and its ways with their geometry. It stops at the geometry the
    /// runner hands inline — nodes are the survey's question, the one that chains a lap.
    pub def ways(relation: Int64): String =
        "[out:json][timeout:90];relation(${relation});out body;way(r);out geom;"
}
