/// The circuits this project writes, and the figures every drawing and report is laid
/// from.
///
/// A circuit's config is authored once, here: the relation surveyed, the length the lap
/// is stretched to, where the circuit puts its own timing line, whose map the lines come
/// from. The directory named by the circuit's word keeps the evidence — the kept Overpass
/// answer and the kept atlas line — and no code. The timing report reads these
/// same figures through this module's own `timingMap`, which derives the
/// report's answer from them rather than restating them; the byte fence — `nix
/// run .#geometry -- survey <word>` — lays them against the bytes the app is
/// served.
///
/// A circuit's atlas layer is here as the URL of the layer itself: the track-atlas line
/// is authored in no config, and the reading that measures it writes its own file beside
/// the circuit — `Atlas.flix`'s, kept at `keptAtlas`.
pub mod Circuit {

    use Geodesy.Place
    use Motorsport.Circuit.TimingMap

    /// Where the line the lap is measured from is put by the circuit itself. A circuit that
    /// publishes no place tags nothing a survey could mistake for it, and is asked nothing.
    pub type alias TimingLine = {
        place  = Place,
        within = Option[Float64]
    }

    /// Whose map the lines the lap is timed to come from. `published` is one map the circuit
    /// itself publishes — its stretches add up to the lap, and it travels into the geometry as
    /// `sectors`, so a check of the lines reads the file rather than a config; `eachSeason`
    /// says why the organiser's map answers for one season only, and is what the timing report
    /// quotes when it refuses a round here. Only one of the two is ever filled.
    pub type alias Lines = {
        published  = Option[Publishes],
        eachSeason = Option[String]
    }

    /// The authored stretches, and the map they were copied from. The same pair a kept
    /// geometry carries of them, which is what `Midline.sectorsClaimed` reads back out of
    /// the file and what the timing report names its lines from.
    pub type alias Publishes = {
        source    = String,
        stretches = List[Float64]
    }

    /// One intermediate timing line the published stretches imply, named as the
    /// geometry names it: a line is `s2` because the second sector begins at it.
    pub type alias ImpliedLine = {
        id     = String,
        metres = Float64
    }

    /// The intermediate lines one circuit's published stretches imply, in the order a
    /// car drives them: each stretch ends where the next begins, and the last ends at
    /// the line the lap is measured from — which is where the lap started, so it is
    /// not a line to place. The stretches are trusted with the lap length they add up
    /// to and nothing else, at `stretchTolerance`.
    ///
    /// This is the one spelling of the rule, in the one module both readers compile:
    /// `Midline.sectorLines` lays these for the drawing and
    /// `TimingLines.Feed.publishedLines` for the report, each wrapping the refusal in
    /// its own error type. The naming — `s2` for the second sector's start — is the
    /// rule the geometry is written under and the report prints by, and they cannot
    /// now disagree about it.
    pub def impliedLines(stretches: List[Float64], lap: Float64): Result[String, List[ImpliedLine]] =
        let total = List.foldLeft((sum, stretch) -> sum + stretch, 0.0, stretches);
        if (Float64.abs(total - lap) > stretchTolerance())
            Err("the sectors add up to ${Util.Format.spelled(total)} m, not the published ${Util.Format.spelled(lap)} m")
        else
            Ok(implied(Option.getWithDefault(Nil, List.init(stretches)), 0.0, 2, Nil))

    /// The lines the stretches imply, in order, each named for the sector that begins
    /// at it — the second sector begins at `s2`, which is why the counting starts
    /// there and not at one.
    def implied(stretches: List[Float64], at: Float64, sector: Int32, lines: List[ImpliedLine]): List[ImpliedLine] =
        match stretches {
            case Nil => List.reverse(lines)
            case one :: more =>
                let standing = at + one;
                implied(more, standing, sector + 1, {id = "s${sector}", metres = standing} :: lines)
        }

    /// One circuit: what was surveyed, what the circuit says the survey is worth, and
    /// where the file it draws lands.
    pub type alias Circuit = {
        relation = Int64,
        // The word the summaries send for the circuit, which names its directory, its
        // kept answer and the file the app reads.
        word     = String,
        // The relation member the lap is measured from. A relation may tag more than one
        // line, and every metre is measured from whichever one was answered to.
        timedFrom = String,
        timingLine = Option[TimingLine],
        // The length the surveyed line is stretched to, in the circuit's own metres.
        lap      = Float64,
        sectors  = Lines,
        // The geometry file, from the directory the command was asked from.
        file     = String,
        // The track-atlas layer measured against this circuit's line, if one is read at
        // all. It is the URL of the layer itself — the reading writes its own file.
        atlas    = Option[String],
        // The prose the geometry file documents its survey with.
        survey   = String
    }

    /// How far a relation's node may stand from the published line and still be it: the
    /// relation tags the line itself, so the distance allowed is the map's own crosshair.
    /// The atlas reading allows a wider distance — `Midline.measuredWithin`.
    pub def nodeWithin(): Float64 = 10.0

    /// How far a circuit's published stretches may miss the lap they are trusted to
    /// add up to. Asked once, by `impliedLines`.
    pub def stretchTolerance(): Float64 = 0.15

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
        atlas    = Some("https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/circuit-de-la-sarthe/raw/layers/24h.geojson"),
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
        atlas  = Some("https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/circuit-of-the-americas/raw/layers/gp.geojson"),
        survey = "The Circuit of the Americas"
    }

    /// The circuits there are, in the order a run over all of them walks them.
    pub def circuits(): List[Circuit] =
        cota() :: leMans() :: Nil

    /// A circuit by the word the app draws it by — the word its directory and its kept
    /// files are named by too.
    pub def byWord(word: String): Option[Circuit] =
        List.find(circuit -> circuit#word == word, circuits())

    /// What the timing report lays its sector shares against, derived from this
    /// config: the published stretches with the lap they add up to, a refusal
    /// quoting the circuit's own reason where its map is re-issued every season,
    /// and `Unsurveyed` for a word no config authors. Held here rather than in
    /// the report's `Motorsport.Circuit` because these are the figures the
    /// drawing is laid from, and a report that reads its answers from the one
    /// authorship needs no fence to tie two copies of them together.
    pub def timingMap(word: String): TimingMap =
        match byWord(word) {
            case None => TimingMap.Unsurveyed
            case Some(circuit) =>
                match circuit#sectors#published {
                    case Some(publishes) =>
                        TimingMap.Published({lapLength = circuit#lap, stretches = publishes#stretches})
                    case None =>
                        match circuit#sectors#eachSeason {
                            case Some(reason) => TimingMap.PerSeason(reason)
                            case None         => TimingMap.Unsurveyed
                        }
                }
        }

    /// The Overpass answer a kept geometry was drawn from, kept beside the config that
    /// surveyed it: evidence the regeneration fence reads, never bytes the app asks for.
    pub def keptAnswer(circuit: Circuit): String =
        keptIn(circuit, keptAnswerName())

    /// The measured line kept beside the same config: the atlas reading's own file,
    /// in this repository's profile at the line's own length — kept beside the circuit
    /// and never served.
    pub def keptAtlas(circuit: Circuit): String =
        keptIn(circuit, keptAtlasName())

    def keptIn(circuit: Circuit, name: String): String =
        "${evidenceDir()}/${circuit#word}/${name}"

    // ------------------------------------------------------- where a circuit's files are

    /// The directory a circuit keeps its evidence in: one per circuit, named by the
    /// circuit's word.
    pub def evidenceDir(): String =
        "circuits"

    /// The directory the app is served its geometries from, which is where the app
    /// reaches for a circuit's file. A circuit's own file stays authored in its config
    /// rather than derived from this, and `TestCircuit` holds it to the word.
    pub def servedDir(): String =
        "app/static/geometry"

    /// The name the Overpass answer is kept under in a circuit's own directory.
    pub def keptAnswerName(): String =
        "overpass.json"

    /// The name the measured atlas line is kept under beside it.
    pub def keptAtlasName(): String =
        "atlas.geojson"

    /// The names that say a directory was made to keep a circuit's evidence — the ones
    /// the two builders above write, and the ones the fence's warning looks for in a
    /// directory it listed. The warning is the reading that can be wrong unnoticed: a
    /// name spelled a third time somewhere is a directory it stops calling out, and a
    /// fence that stays green.
    pub def keptNames(): List[String] =
        keptAnswerName() :: keptAtlasName() :: Nil

    /// A path's last part: the name a file is known by where a directory has been
    /// listed rather than a path authored. Everything above the name is dropped rather
    /// than trusted to match, since the two sides of such a comparison are spelled by
    /// different means.
    pub def lastPart(path: String): String =
        match String.splitOn({substr = "/"}, path) |> List.filter(part -> part != "") {
            case Nil   => ""
            case parts => Option.getWithDefault("", List.last(parts))
        }

    /// The sentence for a word no circuit answers to, naming the words that do.
    pub def unknown(word: String): String =
        "no circuit is surveyed under '${word}': known are ${String.intercalate(", ", List.map(circuit -> circuit#word, circuits()))}"
}
