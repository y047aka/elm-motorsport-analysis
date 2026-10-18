/// Which circuit a round was run on. The summary sends `jsonValue` for it, and
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
    /// on to choose a drawing. Nothing checks the two sides against each other,
    /// as nothing checks `Direction.jsonValue`'s either: a circuit named here and
    /// not drawn app-side is a round drawn as a ring.
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

}
