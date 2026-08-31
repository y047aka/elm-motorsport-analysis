mod Cli.Db.TestJdbc {

    use Cli.Db
    use Cli.Db.Jdbc

    /// The database `nix run .#cli-test` brings up and names in `DATABASE_URL`.
    /// A run that reaches no database fails these rather than skipping them:
    /// the point of them is the half of the boundary no compiler sees.
    def connected(f: Unit -> Result[String, a] \ ef): Result[String, a] \ (ef - Db) + IO =
        let url = Sys.Env.runWithIO(() -> Sys.Env.getVar("DATABASE_URL"))
            |> Option.getWithDefault("");
        match Jdbc.connect(url) {
            case Err(e)   => Err(e)
            case Ok(conn) =>
                let result = Jdbc.runWith(conn, f);
                Jdbc.close(conn);
                result
        }

    @Test
    def aFetchReadsBackTextAndNulls(): Unit \ {Assert, IO} =
        let result = connected(() -> Cli.Db.fetch("select 'a', null::text, 42, null::int"));
        Assert.assertTrue(result == Ok((Some("a") :: None :: Some("42") :: None :: Nil) :: Nil))

    @Test
    def aFetchReadsEveryRowInTheOrderAsked(): Unit \ {Assert, IO} =
        let result = connected(() -> Cli.Db.fetch("select n from generate_series(3, 1, -1) as n"));
        Assert.assertTrue(result == Ok(
            (Some("3") :: Nil) :: (Some("2") :: Nil) :: (Some("1") :: Nil) :: Nil
        ))

    @Test
    def aFetchWithNoRowsIsEmptyRatherThanAnError(): Unit \ {Assert, IO} =
        let result = connected(() -> Cli.Db.fetch("select 1 where false"));
        Assert.assertTrue(result == Ok(Nil))

}
