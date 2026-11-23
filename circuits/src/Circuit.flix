/// The circuits this project writes, and the figures every drawing and report is laid
/// from.
///
/// A circuit's config is authored once, here: the relation surveyed — or, where
/// OpenStreetMap holds no relation, the box whose raceway ways are chained by standing
/// at the authored line — and where the circuit puts its own timing line.
/// The length the lap is stretched to and the stretches it is timed in are the circuit
/// map's, read from the record the app is served (`mapOf`) as `Figures`.
/// The directory named by the circuit's word keeps the evidence — the kept Overpass
/// answer — and no code. The timing report derives its answer from the figures through
/// `timingMapOf`; the byte fence — `nix run .#geometry -- survey <word>`
/// — lays them against the bytes the app is served.
///
/// The steps a circuit joins by are the repository's `/skill:add-circuit` to say.
pub mod Circuit {

    use Geodesy.Place
    use Motorsport.Circuit.TimingMap
    use Util.Json.Json

    /// Where the line the lap is measured from is put by the circuit itself. A circuit that
    /// publishes no place tags nothing a survey could mistake for it, and is asked nothing.
    pub type alias TimingLine = {
        place  = Place,
        within = Option[Float64]
    }

    /// What a circuit map gives: the length the lap is stretched to, and the stretches its
    /// intermediate lines imply, which travel into the geometry as `sectors`.
    pub type alias Figures = {
        lap       = Float64,
        published = Option[Publishes]
    }

    /// The authored stretches, and the map they were copied from. The same pair a kept
    /// geometry carries of them, and what the timing report names its lines from.
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
    /// `TimingLines.Feed.publishedLines` lays these for the report, wrapping the refusal
    /// in its own error type. The naming — `s2` for the second sector's start — is the
    /// rule the geometry is written under and the report prints by.
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
        // names no members, and neither does a relation that tags no member at its line:
        // either one's line is the `timingLine`'s place itself.
        timedFrom = String,
        timingLine = Option[TimingLine],
        // Where the heights of the surveyed places are asked, if anywhere: a source
        // covers its own country, so each circuit names the one that covers it.
        elevation = Option[Elevation.Source],
        // The geometry file, from the directory the command was asked from.
        file     = String,
        // The prose the geometry file documents its survey with.
        survey   = String
    }

    /// How far a relation's node may stand from the published line and still be it: the
    /// relation tags the line itself, so the distance allowed is the map's own crosshair.
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
    /// measures from and so where the lap's zero stands.
    def leMans(): Circuit = {
        relation = Some(2126739i64),
        box      = None,
        pit      = None,
        word     = "le_mans",
        timedFrom = "start-finish",
        timingLine = None,
        elevation = Some(Elevation.Source.IgnLidarHd),
        file     = "app/static/geometry/le_mans.geojson",
        survey   = "The Circuit de la Sarthe"
    }

    /// The Circuit of the Americas. The relation tags two nodes 297 m apart along the lap —
    /// the series' 2026 map gives the start line the same offset — and `finish` is the one
    /// the lap is timed across; the circuit's own sector map puts that line at the place
    /// below.
    def cota(): Circuit = {
        relation = Some(6537729i64),
        box      = None,
        pit      = None,
        word     = "cota",
        timedFrom = "finish",
        timingLine = Some({place = {lon = -97.6422583, lat = 30.1335278}, within = Some(10.0)}),
        elevation = Some(Elevation.Source.Usgs3dep),
        file   = "app/static/geometry/cota.geojson",
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
    /// circuit publishes no distance for the line, so the place authored is the
    /// `start_finish` marker of the tobi/track-atlas dataset — a point that dataset
    /// placed on OpenStreetMap's own centreline, not a measurement of its own. The node
    /// stands about 15 m from it, within the 25 m allowed.
    def barcelona(): Circuit = {
        relation = Some(284540i64),
        box      = None,
        pit      = None,
        word     = "barcelona",
        timedFrom = "finish",
        timingLine = Some({place = {lon = 2.262122, lat = 41.571101}, within = Some(25.0)}),
        elevation = Some(Elevation.Source.IcgcMet2),
        file   = "app/static/geometry/barcelona.geojson",
        survey = "The Circuit de Barcelona-Catalunya"
    }

    /// Monza. The relation `284565` carries its 20 lap ways under no role at all
    /// and names its pit under `pit_lane`. Its `start` and `finish` roles both name
    /// one node — and that node is a `highway=traffic_signals` point, the pit-exit
    /// light — so no role is named, and the lap is turned at the authored place.
    /// That place is the series' 2026 map's finish line, which no source gives in degrees:
    /// the map, laid over the survey, puts its finish line, its pit-in line and i2 between
    /// 298 and 334 m before the light, and the place is the survey's point 320 m before it.
    /// The map is drawn wider than the circuit, so the place is good to some 20 m.
    def monza(): Circuit = {
        relation = Some(284565i64),
        box      = None,
        pit      = None,
        word     = "monza",
        timedFrom = "",
        timingLine = Some({place = {lon = 9.280768, lat = 45.616101}, within = Some(25.0)}),
        elevation = Some(Elevation.Source.LombardiaDtm5),
        file   = "app/static/geometry/monza.geojson",
        survey = "The Autodromo Nazionale di Monza"
    }

    /// Fuji. OpenStreetMap holds no relation for this circuit at all — the probe of its
    /// ground answers nothing — so it is surveyed from a box: every `highway=raceway`
    /// way the ground holds, of which one closed line is the lap, `Pit lane` is the pit
    /// the `pit` field names — the other hanger is a 123 m unnamed connector — and the
    /// drift course, short circuit, kart track and abandoned stubs are what no line
    /// passes and a box survey therefore leaves out.
    /// No node stands at the line, so the zero stands on the authored place alone, and a
    /// place better sourced than this one moves the drawn zero and every Fuji baseline with it.
    /// That place is the series' 2026 map's finish line, which no source gives in degrees:
    /// the map, laid over the survey, puts its finish line, start line, i1 and i2 between 59
    /// and 99 m before the tobi/track-atlas `start_finish` marker the zero stood at, and
    /// the place is the survey's point 80 m before that marker, good to some 20 m.
    def fuji(): Circuit = {
        relation = None,
        box      = Some({south = 35.3397, west = 138.8927, north = 35.3997, east = 138.9527}),
        pit      = Some(148621414i64 :: Nil),
        word     = "fuji",
        timedFrom = "",
        timingLine = Some({place = {lon = 138.926737, lat = 35.371955}, within = Some(25.0)}),
        elevation = Some(Elevation.Source.GsiDem),
        file   = "app/static/geometry/fuji.geojson",
        survey = "The Fuji Speedway"
    }

    /// The circuits there are, in the order a run over all of them walks them.
    pub def circuits(): List[Circuit] =
        cota() :: leMans() :: barcelona() :: monza() :: fuji() :: Nil

    /// A circuit by the word the app draws it by — the word its directory and its kept
    /// files are named by too.
    pub def byWord(word: String): Option[Circuit] =
        List.find(circuit -> circuit#word == word, circuits())

    /// What the timing report lays its sector shares against: the map's stretches with the
    /// lap they add up to, or nothing where the map places no intermediate lines.
    pub def timingMapOf(figures: Figures): TimingMap =
        match figures#published {
            case Some(publishes) => TimingMap.Published({lapLength = figures#lap, stretches = publishes#stretches})
            case None            => TimingMap.Unsurveyed
        }

    // ------------------------------------------------------------- the circuit's map

    /// The record of a circuit's map: the file the app is served it from, named by the
    /// circuit's word.
    pub def mapOf(circuit: Circuit): String =
        "${mapDir()}/${circuit#word}.json"

    /// The directory the app is served the circuit maps from.
    pub def mapDir(): String =
        "app/static/circuit-maps"

    /// A map record read: the centreline is the lap, and the intermediate lines, where the
    /// map gives both, imply the three stretches. Lines out of order are refused.
    /// A stretch is the difference of two printed distances, and is held to the hundredth
    /// of a metre the most precise map prints, so that it is written as the map prints it
    /// and not as the double the subtraction left.
    pub def figuresOf(text: String): Result[String, Figures] =
        match Util.Json.parse(text) {
            case Err(problem) => Err("the map record is no JSON: ${problem}")
            case Ok(json) =>
                forM(
                    season <- wholeAt("season" :: Nil, json);
                    lap    <- metresAt("lengths" :: "centerline" :: "metres" :: Nil, json);
                    i1     <- optionalMetresAt("lines" :: "intermediate1" :: "metres" :: Nil, json);
                    i2     <- optionalMetresAt("lines" :: "intermediate2" :: "metres" :: Nil, json);
                    _      <- inOrder(lap, List.filterMap(identity, i1 :: i2 :: Nil))
                ) yield {
                    lap = lap,
                    published = match (i1, i2) {
                        case (Some(first), Some(second)) =>
                            Some({
                                source = "the ${season} circuit map",
                                stretches = List.map(hundredth, first :: (second - first) :: (lap - second) :: Nil)
                            })
                        case _ => None
                    }
                }
        }

    /// The lines a record places stand in the order a car reaches them, all of them before the
    /// finish line closes the lap: a survey laid from lines out of order fails nowhere else.
    def inOrder(lap: Float64, lines: List[Float64]): Result[String, Unit] =
        let stops = List.append(0.0 :: lines, lap :: Nil);
        if (List.forAll(pair -> match pair { case (one, next) => one < next }, List.zip(stops, List.drop(1, stops))))
            Ok(())
        else
            Err("the map's lines do not stand in order round its ${Util.Format.whole(lap)} m lap")

    def hundredth(metres: Float64): Float64 =
        Float64.round(metres * 100.0) / 100.0

    def at(path: List[String], json: Json): Option[Json] =
        match path {
            case Nil => Some(json)
            case key :: rest =>
                match json {
                    case Json.JObject(members) => Map.get(key, members) |> Option.flatMap(at(rest))
                    case _                               => None
                }
        }

    def numberAt(path: List[String], json: Json): Result[String, Option[Float64]] =
        match at(path, json) {
            case None => Ok(None)
            case Some(Json.JNumber(spelled)) =>
                match Float64.fromString(BigDecimal.toPlainString(spelled)) {
                    case Some(number) => Ok(Some(number))
                    case None         => Err("the map record's ${String.intercalate(".", path)} is a number no double reads")
                }
            case Some(_) => Err("the map record's ${String.intercalate(".", path)} is not a number")
        }

    def metresAt(path: List[String], json: Json): Result[String, Float64] =
        numberAt(path, json) |> Result.flatMap(found -> Option.toOk("the map record gives no ${String.intercalate(".", path)}", found))

    def optionalMetresAt(path: List[String], json: Json): Result[String, Option[Float64]] =
        numberAt(path, json)

    def wholeAt(path: List[String], json: Json): Result[String, Int64] =
        metresAt(path, json) |> Result.map(number -> Float64.truncateToInt64(Float64.round(number)))

    /// The Overpass answer a kept geometry was drawn from, kept beside the config that
    /// surveyed it: evidence the regeneration fence reads, never bytes the app asks for.
    pub def keptAnswer(circuit: Circuit): String =
        keptIn(circuit, keptAnswerName())

    /// The heights the kept answer's places were sampled at, kept beside it: evidence the
    /// survey and the regeneration fence read, since neither reaches a network.
    pub def keptElevation(circuit: Circuit): String =
        keptIn(circuit, keptElevationName())

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

    /// The name the sampled heights are kept under in a circuit's own directory.
    pub def keptElevationName(): String =
        "elevation.json"

    /// The names that say a directory was made to keep a circuit's evidence — the ones
    /// `keptAnswer` and `keptElevation` write, and the ones the fence's warning looks for in a
    /// directory it listed. The warning is the reading that can be wrong unnoticed: a
    /// name spelled a second time somewhere is a directory it stops calling out, and a
    /// fence that stays green.
    pub def keptNames(): List[String] =
        keptAnswerName() :: keptElevationName() :: Nil

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
