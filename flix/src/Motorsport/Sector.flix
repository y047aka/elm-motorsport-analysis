/// The three sectors every WEC circuit is timed to -- the counterpart of
/// `Motorsport.MiniSector` at the coarser grain, and the mirror of
/// `Motorsport.Sector` on the Elm side.
///
/// The RawLap spells its sector columns out flat as `s1`/`s2`/`s3`; this type
/// is what lets one fold run over all three.
mod Motorsport.Sector {

    pub enum Sector with Eq {
        case S1
        case S2
        case S3
    }

    /// In the order a car drives them.
    pub def all(): List[Sector] =
        List#{Sector.S1, Sector.S2, Sector.S3}

    /// JSON object key, matching the field names of the Elm `BySector`.
    pub def jsonKey(sector: Sector): String =
        match sector {
            case Sector.S1 => "s1"
            case Sector.S2 => "s2"
            case Sector.S3 => "s3"
        }

}
