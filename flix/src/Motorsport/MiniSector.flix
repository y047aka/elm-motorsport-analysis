/// Le Mans 24h mini-sectors. The 15 named segments live alongside the
/// standard S1/S2/S3 split and only appear in the Le Mans CSV; other WEC
/// rounds omit these columns entirely. This module is the single source of
/// truth for the IDs, their CSV column prefixes, and their JSON object
/// keys, mirroring `Motorsport.Circuit.LeMans.miniSectorOrder` on the Elm
/// side.
mod Motorsport.MiniSector {

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

    /// Track-order list — must match Motorsport.Circuit.LeMans.miniSectorOrder.
    /// Line groups correspond to S1 / S2 / S3.
    pub def all(): List[MiniSectorId] =
        List#{
            MiniSectorId.SCL2, MiniSectorId.Z4, MiniSectorId.IP1,
            MiniSectorId.Z12, MiniSectorId.SCLC, MiniSectorId.A7_1, MiniSectorId.IP2,
            MiniSectorId.A8_1, MiniSectorId.SCLB, MiniSectorId.PORIN, MiniSectorId.POROUT,
            MiniSectorId.PITREF, MiniSectorId.SCL1, MiniSectorId.FORDOUT, MiniSectorId.FL
        }

    /// CSV column prefix. A7_1 / A8_1 map to the hyphenated `A7-1` / `A8-1`
    /// (the Flix identifier underscore is a syntax constraint, not part of
    /// the column name). Each prefix yields two columns: `_time` and `_elapsed`.
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

    /// JSON object key — lower-case `csvName` with the hyphen reverted to an
    /// underscore (matches the Elm `Motorsport.Lap.MiniSectors` field names).
    pub def jsonKey(id: MiniSectorId): String =
        match id {
            case MiniSectorId.SCL2    => "scl2"
            case MiniSectorId.Z4      => "z4"
            case MiniSectorId.IP1     => "ip1"
            case MiniSectorId.Z12     => "z12"
            case MiniSectorId.SCLC    => "sclc"
            case MiniSectorId.A7_1    => "a7_1"
            case MiniSectorId.IP2     => "ip2"
            case MiniSectorId.A8_1    => "a8_1"
            case MiniSectorId.SCLB    => "sclb"
            case MiniSectorId.PORIN   => "porin"
            case MiniSectorId.POROUT  => "porout"
            case MiniSectorId.PITREF  => "pitref"
            case MiniSectorId.SCL1    => "scl1"
            case MiniSectorId.FORDOUT => "fordout"
            case MiniSectorId.FL      => "fl"
        }

    /// True when `blanks` matches one of the known Ford-chicane track-limits
    /// signatures observed at Le Mans 2025: `SCL1+FORDOUT` (second chicane)
    /// or `PITREF+SCL1` (first chicane). Assumes the input is in track order.
    pub def isTrackLimitsSignature(blanks: List[MiniSectorId]): Bool =
        blanks == List#{MiniSectorId.SCL1, MiniSectorId.FORDOUT}
            or blanks == List#{MiniSectorId.PITREF, MiniSectorId.SCL1}

}
