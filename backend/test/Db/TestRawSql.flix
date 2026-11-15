pub mod Db.TestRawSql {

    /// The marker is raised for each statement as it goes out, which is the
    /// whole of what it does -- and `runWithAllow` is what closes it, so a
    /// handler of the marker's own has to go inside one.
    @Test
    def theMarkerNamesEachStatementAsItGoesOut(): Unit \ Assert =
        region rc {
            let seen = Ref.fresh(rc, (Nil: List[String]));
            discard run {
                Db.runWithError(() -> {
                    Db.execute("SAVEPOINT round");
                    Db.execute("RELEASE SAVEPOINT round")
                })
            } with handler RawSql {
                def allow(sql, k) = {
                    Ref.put(sql :: Ref.get(seen), seen);
                    k(())
                }
            } with handler SqlWrite {
                def execute(_sql, k) = k(Ok())
                def insertMany(_sql, _rows, k) = k(Ok(0))
                def commit(k) = k(Ok())
                def rollback(k) = k(Ok())
            };
            Assert.assertTrue(
                List.reverse(Ref.get(seen)) == "SAVEPOINT round" :: "RELEASE SAVEPOINT round" :: Nil
            )
        }

    /// A `SELECT` is a statement like any other, and is named too.
    @Test
    def theMarkerNamesASelectWithItsParameters(): Unit \ Assert =
        region rc {
            let seen = Ref.fresh(rc, (Nil: List[String]));
            discard run {
                Db.runWithError(() -> discard Db.fetch("SELECT n FROM t WHERE round_id = ?",
                    Db.Value.Integer(7) :: Nil))
            } with handler RawSql {
                def allow(sql, k) = {
                    Ref.put(sql :: Ref.get(seen), seen);
                    k(())
                }
            } with handler SqlRead {
                def fetch(_sql, _params, k) = k(Ok(Nil))
            };
            Assert.assertTrue(List.reverse(Ref.get(seen)) == "SELECT n FROM t WHERE round_id = ?" :: Nil)
        }

}
