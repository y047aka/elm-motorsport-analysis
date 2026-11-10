/// The circuits this project writes, and the figures every drawing and report is laid
/// from.
///
/// A circuit's config is authored once, here: the relation surveyed — or, where
/// OpenStreetMap holds no relation, the box whose raceway ways are chained by standing
/// at the authored line — the length the lap is stretched to, where the circuit puts its
/// own timing line, whose map the lines come
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
///
/// The steps a circuit joins by are the repository's `/skill:add-circuit` to say.
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
    /// quotes when it refuses a round here. Only one of the two is ever filled — or
    /// neither, for a circuit whose map has never been read: it writes no `sectors` and
    /// the report reads it as publishing nothing.
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
    /// at it.
    def implied(stretches: List[Float64], at: Float64, sector: Int32, lines: List[ImpliedLine]): List[ImpliedLine] =
        match stretches {
            case Nil => List.reverse(lines)
            case one :: more =>
                let standing = at + one;
                implied(more, standing, sector + 1, {id = "s${sector}", metres = standing} :: lines)
        }

    /// The ground a box-surveyed circuit is asked of: OpenStreetMap's own
    /// south,west,north,east extent.
    pub type alias Box = {
        south  = Float64,
        west   = Float64,
        north  = Float64,
        east   = Float64
    }

    /// The extent a box is asked and echoed with, in the order Overpass takes it.
    pub def extent(box: Box): String =
        "${box#south},${box#west},${box#north},${box#east}"

    /// One circuit: what was surveyed, what the circuit says the survey is worth, and
    /// where the file it draws lands.
    pub type alias Circuit = {
        // The two groundings, exactly one of them filled: the relation the ways are
        // named by, or the box whose raceway ways are chained by standing at the line.
        relation = Option[Int64],
        box      = Option[Box],
        // The ways the pit lane is, named by id. Only a box needs it: a relation tags
        // its pit members, and a box's ground may hold more than one line hanging off
        // the lap — which of them is the pit is a reading of names and turns, and the
        // survey reads geometry and one-way tags alone.
        pit      = Option[List[Int64]],
        // The word the summaries send for the circuit, which names its directory, its
        // kept answer and the file the app reads.
        word     = String,
        // The relation member the lap is measured from. A relation may tag more than one
        // line, and every metre is measured from whichever one was answered to. A box
        // names no members, and its line is the `timingLine`'s place itself.
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

    /// How far a box's surveyed lap may miss the published one, as a share of it. Every
    /// kept survey lands within a quarter percent of the length it was stretched to; a
    /// box picks its lap by standing near the line alone, and this is what refuses a
    /// shorter course silently inflated to the published figure.
    pub def lengthTolerance(): Float64 = 0.02

    /// Le Mans. The relation tags one node `start-finish`, which is where the organiser
    /// measures from and so where the lap's zero stands; its map is re-issued every season
    /// and its lines differ between them, so no `sectors` travel in the geometry.
    def leMans(): Circuit = {
        relation = Some(2126739i64),
        box      = None,
        pit      = None,
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
        relation = Some(6537729i64),
        box      = None,
        pit      = None,
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

    /// The Circuit de Barcelona-Catalunya, in the layout the WEC races here: the
    /// relation `284540` names itself "Grand Prix Circuit Without Chicane", the lap
    /// the 2023 chicane grew out of and the one kept for racing series the chicane
    /// was built for F1 alone. The chicane relation `2049529` stands beside it in
    /// OpenStreetMap and is the one this app surveyed until the WEC round came; the
    /// two share little more than four ways, so the two drawings differ wherever a
    /// mapper split them apart and the diff measures how far.
    ///
    /// The relation tags `start` and `finish` as two nodes carrying
    /// `raceway=start`/`raceway=finish`; the lap is timed across `finish`. The
    /// circuit publishes no distance for the line, so its place is seeded from the
    /// track-atlas line's `start_finish` marker, at that reading's
    /// `measuredWithin` — the node stands about 15 m from the marker, which is
    /// within it.
    ///
    /// The distances the FIA issues round a lap here were never read at authoring: no
    /// stretches are authored, the geometry writes no `sectors`, and the timing report
    /// reads this circuit as publishing no lines of its own.
    def barcelona(): Circuit = {
        relation = Some(284540i64),
        box      = None,
        pit      = None,
        word     = "barcelona",
        timedFrom = "finish",
        timingLine = Some({place = {lon = 2.262122, lat = 41.571101}, within = Some(25.0)}),
        lap      = 4655.0,
        sectors  = {published = None, eachSeason = None},
        file   = "app/static/geometry/barcelona.geojson",
        atlas  = Some("https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/barcelona/raw/layers/gp.geojson"),
        survey = "The Circuit de Barcelona-Catalunya"
    }

    /// Monza. The relation `284565` carries its 20 lap ways under no role at all
    /// and names its pit under `pit_lane`. Its `start` and `finish` roles both name
    /// one node — and that node is a `highway=traffic_signals` point: the pit-exit
    /// light, 197 m after the line the track-atlas reading measures off imagery and
    /// calls `start_finish`. OSM holds no node where that line stands, so no role a
    /// survey could answer does, and no `timingLine` can be authored without the
    /// byte fence refusing every survey of the relation; the drawn zero and start
    /// line of this circuit therefore stand at the pit-exit light. A node joined to
    /// the relation at the atlas marker's place would fix the drawing without
    /// moving a metre of the survey.
    ///
    /// The distances the FIA issues round a lap here were never read at authoring:
    /// no stretches are authored, the geometry writes no `sectors`, and the timing
    /// report reads this circuit as publishing no lines of its own.
    def monza(): Circuit = {
        relation = Some(284565i64),
        box      = None,
        pit      = None,
        word     = "monza",
        timedFrom = "finish",
        timingLine = None,
        lap      = 5793.0,
        sectors  = {published = None, eachSeason = None},
        file   = "app/static/geometry/monza.geojson",
        atlas  = Some("https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/monza/raw/layers/gp.geojson"),
        survey = "The Autodromo Nazionale di Monza"
    }

    /// Fuji. OpenStreetMap holds no relation for this circuit at all — the probe of its
    /// ground answers nothing — so it is the first circuit surveyed from a box: every
    /// `highway=raceway` way the ground holds, of which the lap is the one closed line
    /// that passes where the line stands, the pit is the open line hanging off that
    /// loop — named by id, because a 123 m unnamed connector hangs off it too and the
    /// lane's own `name` is prose this survey does not read — and the drift course, short
    /// circuit, kart track and abandoned stubs are
    /// what no line passes and a box survey therefore leaves out. No node stands at
    /// the line — the lap's nearest is 207 m down it — so the zero of a box survey is
    /// not a node but the projection of the authored place onto the lap, and the place
    /// is the track-atlas layer's `start_finish` marker: the claim of the very layer
    /// whose outline was stitched from these ways.
    ///
    /// The distances the series issue round a lap here were never read at authoring:
    /// no stretches are authored, the geometry writes no `sectors`, and the timing
    /// report reads this circuit as publishing no lines of its own.
    def fuji(): Circuit = {
        relation = None,
        box      = Some({south = 35.3397, west = 138.8927, north = 35.3997, east = 138.9527}),
        pit      = Some(148621414i64 :: Nil),
        word     = "fuji",
        timedFrom = "",
        timingLine = Some({place = {lon = 138.927423, lat = 35.372405}, within = Some(25.0)}),
        // The grand prix lap as the championship measures it: the 2023 6 Hours of Fuji
        // ran 1,044.927 km over 229 laps, which divides to exactly 4,563 m. The surveyed
        // centreline measures 4,553.6 m, 0.2 percent short of it — within what `laidOut`
        // lets a box miss by. Track atlases print 4,549; the race's own arithmetic is
        // the figure kept here, and it is this one the drawing is measured in.
        lap      = 4563.0,
        sectors  = {published = None, eachSeason = None},
        file   = "app/static/geometry/fuji.geojson",
        atlas  = Some("https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/fuji/raw/layers/gp.geojson"),
        survey = "The Fuji Speedway"
    }

    /// The circuits there are, in the order a run over all of them walks them.
    pub def circuits(): List[Circuit] =
        cota() :: leMans() :: barcelona() :: monza() :: fuji() :: Nil

    /// A circuit by the word the app draws it by — the word its directory and its kept
    /// files are named by too.
    pub def byWord(word: String): Option[Circuit] =
        List.find(circuit -> circuit#word == word, circuits())

    /// What the timing report lays its sector shares against, derived from this
    /// config: the published stretches with the lap they add up to, a refusal
    /// quoting the circuit's own reason where its map is re-issued every season,
    /// and `Unsurveyed` for a word no config authors.
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
        "no circuit is surveyed under '${word}': known are ${circuits() |> List.map(circuit -> circuit#word) |> String.intercalate(", ")}"
}
