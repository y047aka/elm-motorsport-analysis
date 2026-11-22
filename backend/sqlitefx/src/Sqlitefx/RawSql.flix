pub mod Sqlitefx.RawSql {

    ///
    /// 生 SQL を全部許す。監査した上で main などの境界で被せる。
    /// thunk の中で投げた JVM の例外は `run` を抜けてから投げ直す（`Db.rethrowing`）。
    ///
    pub def runWithAllow(thunk: Unit -> a \ ef): a \ ef - RawSql =
        let outcome = run {
                Sqlitefx.Db.catchAll(thunk)
            } with handler RawSql {
                def allow(_sql, resume) = resume(())
            };
        Sqlitefx.Db.rethrowing(outcome)

}
