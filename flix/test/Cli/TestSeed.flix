mod Cli.TestSeed {

    use Cli.Db.LapRow
    use Cli.Db.LapRow.Value
    use Cli.Seed

    /// A `COPY laps TO stdout` line: the columns of `Cli.Db.Schema` separated
    /// by tabs, in their order.
    def line(): String =
        String.intercalate("\t",
            "2025" :: "fuji_6h" :: "1" :: "12" :: "HYPERCAR" ::
            "H" :: "Hertz Team JOTA" :: "Porsche" :: "1" ::
            "Will STEVENS" :: "1" :: "95365" :: "0" :: "f" ::
            "23155" :: "0" :: "29928" :: "0" :: "42282" ::
            "2" :: "160.7" :: "95365" :: "39720000" :: "310.5" ::
            "\\N" :: "SF" :: "\\N" :: "\\N" :: Nil
        )

    @Test
    def aLineIsRead(): Unit \ Assert =
        match Seed.toRow(line()) {
            case Err(_)  => Assert.assertTrue(false)
            case Ok(row) =>
                Assert.assertTrue(row#round == "fuji_6h");
                Assert.assertTrue(row#carNumber == "12");
                Assert.assertTrue(row#lapTimeMs == 95365);
                Assert.assertTrue(row#flagAtFl == "SF")
        }

    /// The marker `COPY` writes for a column that had nothing in it, which is
    /// not the empty string a column that held one has.
    @Test
    def theNullMarkerIsNotAValue(): Unit \ Assert =
        match Seed.toRow(line()) {
            case Err(_)  => Assert.assertTrue(false)
            case Ok(row) =>
                Assert.assertTrue(row#pitTimeMs == None);
                Assert.assertTrue(row#miniSectorTimeMs == None);
                Assert.assertTrue(row#carGroup == "H")
        }

    @Test
    def anArrayColumnKeepsItsBlanks(): Unit \ Assert =
        let withArrays = String.replace(
            {src = "\\N\t\\N"},
            {dst = "{20708,NULL}\t{20708,NULL}"},
            line()
        );
        match Seed.toRow(withArrays) {
            case Err(_)  => Assert.assertTrue(false)
            case Ok(row) => Assert.assertTrue(row#miniSectorTimeMs == Some(Some(20708) :: None :: Nil))
        }

    /// A line the file could not have written: read as a row it would be a lap
    /// made of the wrong columns.
    @Test
    def aShortLineIsRefused(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(Seed.toRow("2025\tfuji_6h\t1")))

    /// What the seed writes is what the load bound, column for column.
    @Test
    def theLineIsTheRowTheLoadWouldSend(): Unit \ Assert =
        match Seed.toRow(line()) {
            case Err(_)  => Assert.assertTrue(false)
            case Ok(row) => Assert.assertTrue(
                List.take(4, LapRow.values(row))
                    == Value.Integer(2025) :: Value.Text("fuji_6h") :: Value.Integer(1) :: Value.Text("12") :: Nil
            )
        }

}
