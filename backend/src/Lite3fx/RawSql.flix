/// Every statement a thunk sends is allowed.
///
/// The boundary that has read what it sends is where this goes: the JDBC
/// handler, the test handlers, and `Server`, which answers a route with no
/// database behind it.
pub mod Lite3fx.RawSql {

    pub def runWithAllow(f: Unit -> a \ ef): a \ (ef - RawSql) =
        let outcome = run {
            Lite3fx.Db.catchAll(f)
        } with handler RawSql {
            def allow(_sql, k) = k(())
        };
        Lite3fx.Db.rethrowing(outcome)

}
