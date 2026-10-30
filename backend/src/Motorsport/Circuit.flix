/// Which circuit a round was run on. The summary sends `jsonValue` for the
/// circuit, and that one word is what the app chooses its drawing by.
///
/// A circuit is named by the stem its round ids share, which is what keeps the
/// name holding when a championship runs a second round at a circuit it already
/// draws: `bahrain_8h` and a future `bahrain_1812km` are both `bahrain`. It is
/// not the circuit's own name -- Losail, Interlagos -- because the round ids are
/// the vocabulary a round is already known by end to end, and a second one for
/// the same thing would only give the two a chance to disagree.
///
/// What a circuit publishes about the lines its lap is timed to is not held
/// here: the timing report is the `circuits/` project's, and it derives those
/// figures from the config the drawing is laid from. This module is the wire
/// vocabulary alone -- the word the export writes and the app reads.
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
    /// on to choose a drawing. A circuit named here and not drawn app-side is a
    /// round drawn as a ring, and nothing minds; a drawing reached for by a word
    /// no summary can send is the mistake that passes every compiler, and
    /// `app/tests/geometry-contract.spec.ts` reads this file and `Shared.elm`
    /// to catch it.
    ///
    /// The timing report holds its own copy of these words, in
    /// `circuits/src/Motorsport/Circuit.flix`; `circuits/test/check-sources.mjs`
    /// lays the two bodies together, since no project compiles both.
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

}
