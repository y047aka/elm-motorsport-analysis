/// Le Mans 24 h mini-sectors — single source of truth for IDs, CSV column
/// prefixes, and JSON object keys.
///
/// The 15 named segments live alongside the standard S1/S2/S3 split and only
/// appear in the Le Mans CSV; other WEC rounds omit these columns entirely.
/// This mirrors `Motorsport.Wec.Circuit.LeMans.miniSectorOrder` on the Elm side.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MiniSectorId {
    Scl2,
    Z4,
    Ip1,
    Z12,
    Sclc,
    A7_1,
    Ip2,
    A8_1,
    Sclb,
    Porin,
    Porout,
    Pitref,
    Scl1,
    Fordout,
    Fl,
}

impl MiniSectorId {
    /// Track-order list — must match `Motorsport.Wec.Circuit.LeMans.miniSectorOrder`.
    /// Groups correspond to S1 / S2 / S3.
    pub fn all() -> &'static [Self] {
        use MiniSectorId::*;
        &[
            Scl2, Z4, Ip1,
            Z12, Sclc, A7_1, Ip2,
            A8_1, Sclb, Porin, Porout,
            Pitref, Scl1, Fordout, Fl,
        ]
    }

    /// CSV column prefix. `A7_1` / `A8_1` map to the hyphenated `A7-1` /
    /// `A8-1` (the enum underscore is an identifier constraint, not part of
    /// the column name). Each prefix yields two columns: `_time` and `_elapsed`.
    ///
    /// Not currently consumed by the converter pipeline — the CSV column
    /// names are baked into `stages::csv_input::CsvRow` via `#[serde(rename)]`
    /// attributes. This method exists so the `MiniSectorId` enum is a
    /// complete, self-contained source of truth (matching the Flix
    /// `Motorsport.MiniSector` module) and so future tooling (e.g. CSV
    /// schema generation, reverse export) can look up the names here rather
    /// than re-deriving them.
    #[allow(dead_code)]
    pub fn csv_name(self) -> &'static str {
        match self {
            Self::Scl2   => "SCL2",
            Self::Z4     => "Z4",
            Self::Ip1    => "IP1",
            Self::Z12    => "Z12",
            Self::Sclc   => "SCLC",
            Self::A7_1   => "A7-1",
            Self::Ip2    => "IP2",
            Self::A8_1   => "A8-1",
            Self::Sclb   => "SCLB",
            Self::Porin  => "PORIN",
            Self::Porout => "POROUT",
            Self::Pitref => "PITREF",
            Self::Scl1   => "SCL1",
            Self::Fordout => "FORDOUT",
            Self::Fl     => "FL",
        }
    }

    /// JSON object key — lower-case `csv_name` with the hyphen converted to an
    /// underscore (matches the Elm `Motorsport.Lap.MiniSectors` field names).
    pub fn json_key(self) -> &'static str {
        match self {
            Self::Scl2   => "scl2",
            Self::Z4     => "z4",
            Self::Ip1    => "ip1",
            Self::Z12    => "z12",
            Self::Sclc   => "sclc",
            Self::A7_1   => "a7_1",
            Self::Ip2    => "ip2",
            Self::A8_1   => "a8_1",
            Self::Sclb   => "sclb",
            Self::Porin  => "porin",
            Self::Porout => "porout",
            Self::Pitref => "pitref",
            Self::Scl1   => "scl1",
            Self::Fordout => "fordout",
            Self::Fl     => "fl",
        }
    }
}

/// Returns `true` when `blanks` matches one of the known Ford-chicane
/// track-limits signatures observed at Le Mans 2025:
///   - `[Scl1, Fordout]`   — second chicane
///   - `[Pitref, Scl1]`    — first chicane
///
/// The input must be in track order (same order as `MiniSectorId::all()`).
pub fn is_track_limits_signature(blanks: &[MiniSectorId]) -> bool {
    matches!(
        blanks,
        [MiniSectorId::Scl1, MiniSectorId::Fordout]
            | [MiniSectorId::Pitref, MiniSectorId::Scl1]
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_returns_15_sectors() {
        assert_eq!(MiniSectorId::all().len(), 15);
    }

    #[test]
    fn all_starts_with_scl2_and_ends_with_fl() {
        let all = MiniSectorId::all();
        assert_eq!(all[0], MiniSectorId::Scl2);
        assert_eq!(all[14], MiniSectorId::Fl);
    }

    #[test]
    fn csv_name_hyphen_variants() {
        assert_eq!(MiniSectorId::A7_1.csv_name(), "A7-1");
        assert_eq!(MiniSectorId::A8_1.csv_name(), "A8-1");
    }

    #[test]
    fn json_key_underscore_variants() {
        assert_eq!(MiniSectorId::A7_1.json_key(), "a7_1");
        assert_eq!(MiniSectorId::A8_1.json_key(), "a8_1");
    }

    #[test]
    fn is_track_limits_signature_second_chicane() {
        assert!(is_track_limits_signature(&[
            MiniSectorId::Scl1,
            MiniSectorId::Fordout,
        ]));
    }

    #[test]
    fn is_track_limits_signature_first_chicane() {
        assert!(is_track_limits_signature(&[
            MiniSectorId::Pitref,
            MiniSectorId::Scl1,
        ]));
    }

    #[test]
    fn is_track_limits_signature_rejects_other_patterns() {
        assert!(!is_track_limits_signature(&[MiniSectorId::Fl]));
        assert!(!is_track_limits_signature(&[]));
        assert!(!is_track_limits_signature(&[
            MiniSectorId::Scl1,
            MiniSectorId::Fl,
        ]));
    }
}
