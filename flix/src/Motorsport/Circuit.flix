/// Which circuit a round was run on, and what that circuit publishes about the
/// lines its lap is timed to. The summary sends `jsonValue` for the circuit, and
/// that one word is what the app chooses its drawing by.
///
/// A circuit is named by the stem its round ids share, which is what keeps the
/// name holding when a championship runs a second round at a circuit it already
/// draws: `bahrain_8h` and a future `bahrain_1812km` are both `bahrain`. It is
/// not the circuit's own name -- Losail, Interlagos -- because the round ids are
/// the vocabulary a round is already known by end to end, and a second one for
/// the same thing would only give the two a chance to disagree.
pub mod Motorsport.Circuit {

    pub enum Circuit with Eq {
        case Qatar
        case Imola
        case Spa
        case LeMans
        case Cota
        case Fuji
        case Bahrain
        case SaoPaulo
    }

    /// The spelling the summary sends for it, which is the word the app matches
    /// on to choose a drawing. A circuit named here and not drawn app-side is a
    /// round drawn as a ring, and nothing minds; a drawing reached for by a word
    /// no summary can send is the mistake that passes every compiler, and
    /// `app/tests/geometry-contract.spec.ts` reads this file and `Shared.elm`
    /// to catch it.
    pub def jsonValue(circuit: Circuit): String =
        match circuit {
            case Circuit.Qatar    => "qatar"
            case Circuit.Imola    => "imola"
            case Circuit.Spa      => "spa"
            case Circuit.LeMans   => "le_mans"
            case Circuit.Cota     => "cota"
            case Circuit.Fuji     => "fuji"
            case Circuit.Bahrain  => "bahrain"
            case Circuit.SaoPaulo => "sao_paulo"
        }

    /// The stretches one circuit's map puts round its lap, and the lap length the
    /// map gives, which they add up to.
    pub type alias PublishedMap = {
        lapLength = Float64,
        stretches = List[Float64]
    }

    /// What a circuit publishes about the lines the lap is timed to.
    ///
    /// `Published` is the one map the circuit draws every season with, and the
    /// stretches it puts round the lap; `PerSeason` is a circuit that re-issues
    /// its map, so that no set of lines answers for two seasons and no reading
    /// may lay one season's times against another's; `Unsurveyed` is a circuit
    /// no geometry is kept for, which therefore publishes nothing here.
    ///
    /// Held twice, because the two readings do not meet: the drawing is laid from
    /// the surveyed shape, which the geometry project's `circuits/src/Circuit.flix`
    /// authors, and `Cli.TimingLines` reads these figures and no geometry. The two
    /// copies are laid together by `circuits/test/TestTimingMap.flix`, which
    /// compiles both — the only place they ever stand in one project.
    pub enum TimingMap {
        case Published(PublishedMap)
        case PerSeason(String)
        case Unsurveyed
    }

    /// The lap length a reading places its sector shares against, and the
    /// intermediate lines the published stretches imply. Naming those lines --
    /// `s2` begins the second sector -- is `Cli.TimingLines.Feed`'s
    /// `publishedLines`, which the drawing's own pipeline spells the same way.
    pub def timingMap(circuit: Circuit): TimingMap =
        match circuit {
            case Circuit.Cota =>
                TimingMap.Published({ lapLength = 5515.0, stretches = List#{1313.2, 2254.3, 1947.5} })
            case Circuit.LeMans =>
                TimingMap.PerSeason(
                    "the organiser's map is re-issued every year and its lines differ between seasons"
                )
            case Circuit.Qatar    => TimingMap.Unsurveyed
            case Circuit.Imola    => TimingMap.Unsurveyed
            case Circuit.Spa      => TimingMap.Unsurveyed
            case Circuit.Fuji     => TimingMap.Unsurveyed
            case Circuit.Bahrain  => TimingMap.Unsurveyed
            case Circuit.SaoPaulo => TimingMap.Unsurveyed
        }

}
