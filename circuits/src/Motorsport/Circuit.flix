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
///
/// This is the report's own copy of that vocabulary: the linked
/// `Motorsport/Events.flix` names which ground a round was run on in these
/// cases, and it compiles against whichever copy its project holds. The two
/// copies state one thing in common — the words — and
/// `test/check-sources.mjs` lays the two `jsonValue` bodies together, since no
/// project compiles both. The timing figures are not held here at all: the
/// report's answer is derived by `Circuit.timingMap` from the config the
/// drawing is laid from. This module could not hold that derivation itself —
/// its own `Circuit` shadows the config module of the same name, so
/// `Circuit.byWord` reaches no further than the enum.
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
        case Barcelona
    }

    /// The spelling the summary sends for it, which is the word the app matches
    /// on to choose a drawing, the word the report prints its lines under, and
    /// the word a config names its directory by. A circuit named here and not
    /// drawn app-side is a round drawn as a ring, and nothing minds; a drawing
    /// reached for by a word no summary can send is the mistake that passes
    /// every compiler, and `app/tests/geometry-contract.spec.ts` reads the
    /// export's copy of this vocabulary and `Shared.elm` to catch it.
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
            case Circuit.Barcelona => "barcelona"
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
    /// no config here authors, which therefore publishes nothing.
    ///
    /// The shape of an answer, not a copy of one: `Circuit.timingMap` derives
    /// each circuit's from its authored `sectors`.
    pub enum TimingMap {
        case Published(PublishedMap)
        case PerSeason(String)
        case Unsurveyed
    }

}
