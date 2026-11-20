/// What a result code and the driver's own words were saying, dropped onto
/// which failure it is.
///
/// SQLite's extended result codes carry the primary code in their low byte --
/// `SQLITE_BUSY_SNAPSHOT` is 517, which is 5 -- and the driver answers some
/// refusals with the primary code alone, so a kind is read off the code where
/// the code says it and off the message where it does not.
///
/// Pure, so the table is tested without a database.
pub mod Lite3fx.SqliteState {

    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.DbError.TransientKind

    /// `SQLITE_BUSY` is 5 and `SQLITE_LOCKED` is 6: a lock waited out rather
    /// than got, which is the one refusal that says the same statement may go
    /// through next time.
    def busy(): Int32 = 5
    def locked(): Int32 = 6

    /// `SQLITE_ERROR`, which is what the driver answers a missing table or
    /// column with, and `SQLITE_CONSTRAINT`, which is not one failure.
    def error(): Int32 = 1
    def constraint(): Int32 = 19

    /// The extended codes of `SQLITE_CONSTRAINT`, which the driver answers some
    /// refusals with and others without.
    def constraintCheck(): Int32 = 275
    def constraintForeignKey(): Int32 = 787
    def constraintNotNull(): Int32 = 1299
    def constraintPrimaryKey(): Int32 = 1555
    def constraintRowid(): Int32 = 2579
    def constraintUnique(): Int32 = 2067

    pub def classify(refusal: {code = Int32, message = String}): DbErrorKind =
        let code = refusal#code;
        let message = refusal#message;
        let primary = Int32.remainder(code, 256);
        if (primary == busy() or primary == locked())
            DbErrorKind.Transient(TransientKind.Busy(message))
        else if (primary == constraint())
            constraintKind(code, message)
        else if (primary == error() and missingSchema(message))
            DbErrorKind.SchemaMismatch(message)
        else
            DbErrorKind.Other(message)

    /// Which refusal the constraint is. The extended code says it where the
    /// driver gave one; the message says it where the driver gave the primary
    /// code alone, which is most of them.
    def constraintKind(code: Int32, message: String): DbErrorKind = match code {
        case c if c == constraintUnique() or c == constraintPrimaryKey() or c == constraintRowid() =>
            DbErrorKind.UniqueViolation(name(message))
        case c if c == constraintForeignKey()  => DbErrorKind.ForeignKeyViolation(message)
        case c if c == constraintNotNull()     => DbErrorKind.NotNullViolation(name(message))
        case c if c == constraintCheck()       => DbErrorKind.CheckViolation(name(message))
        case _                                 => kindFromMessage(message)
    }

    /// The message's own words, which is where SQLite names the constraint.
    def kindFromMessage(message: String): DbErrorKind =
        if (String.startsWith({prefix = "UNIQUE constraint failed"}, message))
            DbErrorKind.UniqueViolation(name(message))
        else if (String.startsWith({prefix = "FOREIGN KEY constraint failed"}, message))
            DbErrorKind.ForeignKeyViolation(message)
        else if (String.startsWith({prefix = "NOT NULL constraint failed"}, message))
            DbErrorKind.NotNullViolation(name(message))
        else if (String.startsWith({prefix = "CHECK constraint failed"}, message))
            DbErrorKind.CheckViolation(name(message))
        else
            DbErrorKind.Other(message)

    /// What a missing table or column reads as. The phrase is searched for rather
    /// than matched at the front: the JDBC driver wraps SQLite's own sentence in one
    /// of its own -- `[SQLITE_ERROR] SQL error or missing database (no such table:
    /// laps)` -- so `no such …` is never where the sentence begins.
    def missingSchema(message: String): Bool =
        String.contains({substr = "no such "}, message)
            or String.contains({substr = "no table"}, message)

    /// The constraint or column named after `failed`, which is the one part of
    /// the sentence that says which. Where the message has no such part, the
    /// whole of it is kept rather than nothing.
    def name(message: String): String =
        match String.splitOn({substr = "failed:"}, message) {
            case _ :: rest =>
                String.trim(List.last(rest) |> Option.getWithDefault(message))
            case Nil => message
        }

}
