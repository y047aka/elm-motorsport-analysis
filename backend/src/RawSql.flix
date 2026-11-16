/// Whether a statement's text was written rather than built.
///
/// A marker, not a check: it names the functions that put SQL on the wire, so
/// the ones taking text from further away are enumerable from the signatures
/// rather than from a search. `runWithAllow` goes over the boundaries that have
/// read what they send.
pub eff RawSql {
    /// The statement about to be sent.
    def allow(sql: String): Unit
}

pub mod RawSql {

    /// Every statement the thunk sends is allowed.
    pub def runWithAllow(f: Unit -> a \ ef): a \ (ef - RawSql) =
        let outcome = run {
            Db.catchAll(f)
        } with handler RawSql {
            def allow(_sql, k) = k(())
        };
        Db.rethrowing(outcome)

}
