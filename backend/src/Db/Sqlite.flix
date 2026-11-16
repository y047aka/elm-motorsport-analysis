/// What a result code and the driver's own words were saying, dropped onto
/// which failure it is.
///
/// SQLite's extended result codes carry the primary code in their low byte --
/// `SQLITE_BUSY_SNAPSHOT` is 517, which is 5 -- so one remainder reads both
/// spellings of the same refusal.
pub mod Db.Sqlite {

    /// `SQLITE_BUSY` is 5 and `SQLITE_LOCKED` is 6: a lock waited out rather
    /// than got, which is the one refusal that says the same statement may go
    /// through next time.
    ///
    /// `SQLITE_ERROR` is 1 and `SQLITE_CONSTRAINT` is 19, and both are left as
    /// the driver's sentence.
    pub def classify(refusal: {code = Int32, message = String}): Db.Error =
        match Int32.remainder(refusal#code, 256) {
            case 5 => Db.busy(refusal#message)
            case 6 => Db.busy(refusal#message)
            case _ => Db.Error.Refused(refusal#message)
        }

}
