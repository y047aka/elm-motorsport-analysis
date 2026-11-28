/// The fifteen mini-sectors Le Mans's feed measures a lap in, which ride beside
/// the standard S1/S2/S3 split and come in that round's feed alone. Their ids and
/// their names -- one spelling for the CSV column prefix and for the JSON key --
/// are spelled here and nowhere else on this side of the seam.
pub mod Motorsport.MiniSector {

    use Motorsport.Sector.Sector

    pub enum MiniSectorId with Eq {
        case SCL2
        case Z4
        case IP1
        case Z12
        case SCLC
        case A7_1
        case IP2
        case A8_1
        case SCLB
        case PORIN
        case POROUT
        case PITREF
        case SCL1
        case FORDOUT
        case FL
    }

    /// In track order. The names are the join key across the seam: the drawing's
    /// timing lines (`Wec/Circuit/LeMans/Layout`) and the shares the summary
    /// carries are matched to each other by name, and nothing reads the lists
    /// against each other -- a name spelled one way here and another there puts a
    /// marker in the wrong place, silently.
    pub def all(): List[MiniSectorId] =
        List#{
            MiniSectorId.SCL2, MiniSectorId.Z4, MiniSectorId.IP1,
            MiniSectorId.Z12, MiniSectorId.SCLC, MiniSectorId.A7_1, MiniSectorId.IP2,
            MiniSectorId.A8_1, MiniSectorId.SCLB, MiniSectorId.PORIN, MiniSectorId.POROUT,
            MiniSectorId.PITREF, MiniSectorId.SCL1, MiniSectorId.FORDOUT, MiniSectorId.FL
        }

    /// The line groups of `all` written out. Total by construction, so a
    /// mini-sector cannot go missing from the grouping or land in two sectors.
    pub def sectorOf(id: MiniSectorId): Sector =
        match id {
            case MiniSectorId.SCL2    => Sector.S1
            case MiniSectorId.Z4      => Sector.S1
            case MiniSectorId.IP1     => Sector.S1
            case MiniSectorId.Z12     => Sector.S2
            case MiniSectorId.SCLC    => Sector.S2
            case MiniSectorId.A7_1    => Sector.S2
            case MiniSectorId.IP2     => Sector.S2
            case MiniSectorId.A8_1    => Sector.S3
            case MiniSectorId.SCLB    => Sector.S3
            case MiniSectorId.PORIN   => Sector.S3
            case MiniSectorId.POROUT  => Sector.S3
            case MiniSectorId.PITREF  => Sector.S3
            case MiniSectorId.SCL1    => Sector.S3
            case MiniSectorId.FORDOUT => Sector.S3
            case MiniSectorId.FL      => Sector.S3
        }

    /// The name, in the track order's own spelling. It is the CSV column prefix --
    /// each prefix yields two columns, `_time` and `_elapsed` -- and the JSON key
    /// the file names the mini-sector by, which is what the Elm side joins its
    /// lists on.
    ///
    /// A7_1 / A8_1 map to the hyphenated `A7-1` / `A8-1` (the Flix identifier
    /// underscore is a syntax constraint, not part of the name).
    pub def csvName(id: MiniSectorId): String =
        match id {
            case MiniSectorId.SCL2    => "SCL2"
            case MiniSectorId.Z4      => "Z4"
            case MiniSectorId.IP1     => "IP1"
            case MiniSectorId.Z12     => "Z12"
            case MiniSectorId.SCLC    => "SCLC"
            case MiniSectorId.A7_1    => "A7-1"
            case MiniSectorId.IP2     => "IP2"
            case MiniSectorId.A8_1    => "A8-1"
            case MiniSectorId.SCLB    => "SCLB"
            case MiniSectorId.PORIN   => "PORIN"
            case MiniSectorId.POROUT  => "POROUT"
            case MiniSectorId.PITREF  => "PITREF"
            case MiniSectorId.SCL1    => "SCL1"
            case MiniSectorId.FORDOUT => "FORDOUT"
            case MiniSectorId.FL      => "FL"
        }

    /// The blank patterns a car running off the Ford chicanes leaves: the second
    /// chicane misses `SCL1` and `FORDOUT`, the first `PITREF` and `SCL1`, so a
    /// match is a lap cut short rather than a timing fault. The input is in track
    /// order.
    pub def trackLimitsSignatures(): List[List[MiniSectorId]] =
        List#{MiniSectorId.SCL1, MiniSectorId.FORDOUT} ::
        List#{MiniSectorId.PITREF, MiniSectorId.SCL1} ::
        Nil

    /// Where the marker falls in `all`, counted from one, so that a place in a
    /// list the database holds in track order can be named again.
    pub def positionOf(id: MiniSectorId): Int32 =
        all() |> List.takeWhile(other -> other != id) |> List.length |> x -> x + 1

    pub def atPosition(position: Int32): Option[MiniSectorId] =
        List.nth(position - 1, all())

}
