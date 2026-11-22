pub mod Sqlitefx.TimeZone {

    use Sqlitefx.Zone

    ///
    /// ゾーンを 1 つ決めて thunk を走らせる。
    /// thunk の中で投げた JVM の例外は `run` を抜けてから投げ直す（`Db.rethrowing`）。
    ///
    pub def runWith(zone: Zone.Zone, thunk: Unit -> a \ ef): a \ ef - TimeZone =
        let outcome = run {
                Sqlitefx.Db.catchAll(thunk)
            } with handler TimeZone {
                def zone(resume) = resume(zone)
            };
        Sqlitefx.Db.rethrowing(outcome)

}
