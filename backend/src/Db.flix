/// The application's own side of the database: the tables a round is loaded
/// into, the rows they hold, and the readings out of them.
///
/// Reaching a database is `Sqlitefx`'s, and names no table; what these modules
/// tell it about this sport is here.
pub mod Db {

    /// sqlfx's aliases with `RawSql` inside them: every function here reaches a statement, so the marker would be on every signature and tell none apart.
    pub type alias DbRead = {Sqlitefx.SqlRead, Sqlitefx.TransientDbErr, Sqlitefx.DbErr, Sqlitefx.RawSql}
    pub type alias DbWrite = {Sqlitefx.SqlWrite, Sqlitefx.TransientDbErr, Sqlitefx.DbErr, Sqlitefx.RawSql}
    pub type alias DbAll = {Sqlitefx.SqlRead, Sqlitefx.SqlWrite, Sqlitefx.SqlSavepoint, Sqlitefx.TransientDbErr, Sqlitefx.DbErr, Sqlitefx.RawSql}

    /// The server answers on a pool of eight and connects per request, so a read has to run beside a writing run rather than behind it: WAL, and a wait for a lock rather than a refusal.
    ///
    /// `foreign_keys` stays off, as SQLite leaves it: no key is declared, and the load's own numbering fails a missing round, car or seat by name (`backend/README.md`).
    pub def connection(url: String): Sqlitefx.Jdbc.ConnectionConfig =
        { url = url, pragmas = List#{"journal_mode = WAL", "busy_timeout = 5000"} }

}
