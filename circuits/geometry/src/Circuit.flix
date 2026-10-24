/// The circuits this project writes, in the language the writer is written in.
///
/// A circuit's config is authored once, in `circuits/<word>/circuit.ts`, and what is
/// authored there — the relation surveyed, the length the lap is stretched to, where the
/// circuit puts its own timing line, whose map the lines come from — is held here a second
/// time because Flix reads no TypeScript. That is three holders of one set of figures
/// counting the drawing's own `Motorsport.Circuit`: `app/tests/circuit-timing-map.spec.ts`
/// lays the TypeScript against the Elm, and `circuits-geometry-reading.spec.ts` lays these
/// against both, figure by figure, since a lap length that moves on one side is a survey
/// stretched to a different circuit.
///
/// What is *not* here is a circuit's atlas layer and its geometry script's own name: those
/// belong to the atlas reading and to the TypeScript reports, which are not this project.
pub mod Circuit {

    use Geometry.Place

    /// Where the line the lap is measured from is put by the circuit itself. COTA's comes
    /// off the same document its sector distances come from; Le Mans publishes no place
    /// its relation does not already tag, and so asks nothing of a survey.
    pub type alias TimingLine = {
        place  = Place,
        within = Option[Float64]
    }

    /// Whose map the lines the lap is timed to come from. `published` is one map the
    /// circuit itself publishes — its stretches add up to the lap and it travels into the
    /// geometry as `sectors`, so a check of the lines reads the file rather than a config;
    /// `eachSeason` says why the organiser's map answers for one season only, and is what
    /// the timing report quotes when it refuses a round here. Only one of the two is ever
    /// filled, and which one a circuit fills is the difference the geometry file either
    /// shows or does not.
    pub type alias Lines = {
        published  = Option[Publishes],
        eachSeason = Option[String]
    }

    /// The authored stretches, and the map they were copied from.
    pub type alias Publishes = {
        source    = String,
        stretches = List[Float64]
    }

    /// One circuit: what was surveyed, what the circuit says the survey is worth, and
    /// where the file it draws lands.
    pub type alias Circuit = {
        // The OpenStreetMap relation the survey is read out of.
        relation = Int64,
        // The word the summaries send for the circuit, which names its directory, its
        // kept answer and the file the app reads.
        word     = String,
        // The relation member the lap is measured from. A relation may tag more than one
        // line, and every metre is measured from whichever one was answered to.
        timedFrom = String,
        // How far the line the lap is measured from may stand from the published place
        // and still be it; nothing is asked of a circuit that publishes no place.
        timingLine = Option[TimingLine],
        // The length the surveyed line is stretched to, in the circuit's own metres.
        lap      = Float64,
        // The timing lines, and whose map they came from.
        sectors  = Lines,
        // The geometry file, from the directory the command was asked from.
        file     = String,
        // What the survey is called, in the survey's own words.
        survey   = String
    }

    /// How far a relation's node may stand from the published line and still be it: the
    /// relation tags the line itself, so the distance allowed is the map's own crosshair.
    /// The atlas reading allows a wider distance than this one, and says why there.
    pub def nodeWithin(): Float64 = 10.0

    /// Le Mans. The relation tags one node `start-finish`, which is where the organiser
    /// measures from and so where the lap's zero stands; its map is re-issued every season
    /// and its lines differ between them, so no `sectors` travel in the geometry.
    def leMans(): Circuit = {
        relation = 2126739i64,
        word     = "le_mans",
        timedFrom = "start-finish",
        timingLine = None,
        lap      = 13625.7,
        sectors  = {published = None, eachSeason = Some("the organiser's map is re-issued every year and its lines differ between seasons")},
        file     = "app/static/geometry/le_mans.geojson",
        survey   = "The Circuit de la Sarthe"
    }

    /// The Circuit of the Americas. The relation tags two nodes 297 m apart along the lap,
    /// and `finish` is the one the lap is timed across; the circuit's own sector map puts
    /// that line at the place below, and its three stretches — which add up to the lap
    /// exactly — travel in the geometry because one map serves every season here.
    def cota(): Circuit = {
        relation = 6537729i64,
        word     = "cota",
        timedFrom = "finish",
        timingLine = Some({place = {lon = -97.6422583, lat = 30.1335278}, within = Some(10.0)}),
        lap      = 5515.0,
        sectors  = {
            published = Some({
                source = "the circuit's own track sector map",
                stretches = 1313.2 :: 2254.3 :: 1947.5 :: Nil
            }),
            eachSeason = None
        },
        file   = "app/static/geometry/cota.geojson",
        survey = "The Circuit of the Americas"
    }

    /// The circuits there are, in the order a run over all of them walks them.
    pub def circuits(): List[Circuit] =
        cota() :: leMans() :: Nil

    /// A circuit by the word the app draws it by — the word its directory and its kept
    /// files are named by too.
    pub def byWord(word: String): Option[Circuit] =
        List.find(circuit -> circuit#word == word, circuits())

    /// The Overpass answer a kept geometry was drawn from, kept beside the config that
    /// surveyed it: evidence the regeneration fence reads, never bytes the app asks for.
    pub def keptAnswer(circuit: Circuit): String =
        "circuits/${circuit#word}/overpass.json"

    /// The sentence for a word no circuit answers to, naming the words that do — which is
    /// the reader's own list, read back at them.
    pub def unknown(word: String): String =
        "no circuit is surveyed under '${word}': known are ${String.intercalate(", ", List.map(circuit -> circuit#word, circuits()))}"
}
