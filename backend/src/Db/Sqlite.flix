/// What a result code and the driver's own words were saying, dropped onto
/// which failure it is.
///
/// Pure, so the table is read without a driver: the codes are what they are
/// whatever the database on the other end of the connection happens to be doing.
///
/// SQLite's extended result codes carry the primary code in their low byte --
/// `SQLITE_BUSY_SNAPSHOT` is 517, which is 5 -- so one remainder reads both
/// spellings of the same refusal.
pub mod Db.Sqlite {

    /// `SQLITE_BUSY` is 5 and `SQLITE_LOCKED` is 6: a lock waited out rather
    /// than got, which is the one refusal that says the same statement may go
    /// through next time.
    ///
    /// `SQLITE_ERROR` is 1 and `SQLITE_CONSTRAINT` is 19, and both are the
    /// driver's sentence to say: nothing between here and the caller branches on
    /// which constraint was stepped on.
    pub def classify(refusal: {code = Int32, message = String}): Db.Error =
        match Int32.remainder(refusal#code, 256) {
            case 5 => Db.busy(refusal#message)
            case 6 => Db.busy(refusal#message)
            case _ => Db.Error.Refused(refusal#message)
        }

}
