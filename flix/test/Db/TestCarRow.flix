mod Db.TestCarRow {

    use Db.CarRow
    use Db.Cars
    use Db.Entries
    use Db.TestLapRow
    use Db.Value

    /// The id a run gave the round; see `Db.TestLapRow`.
    def fujiId(): Int32 = 7

    def season(): Int32 = 2025

    /// The entries the sample names, numbered as a run would number them.
    def numbering(): Entries.Numbering =
        let (numbered, _, _) = Entries.add(
            Entries.noneNumbered(), season(), CarRow.firstMentions(TestLapRow.sampleLaps()));
        numbered

    /// Two laps of car 12 and one of car 7, in that order.
    def rows(): List[CarRow.CarRow] =
        match CarRow.fromRawLaps(fujiId(), season(), numbering(), TestLapRow.sampleLaps()) {
            case Some(built) => built
            case None        => Nil
        }

    @Test
    def aCarIsOneRowHoweverManyLapsItRan(): Unit \ Assert =
        Assert.assertTrue(List.map(r -> r#carNumber, rows()) == "12" :: "7" :: Nil)

    @Test
    def theRoundIsTheOneTheLoadNamedAndNotTheFeed(): Unit \ Assert =
        match rows() {
            case row :: _ => Assert.assertTrue(row#roundId == fujiId())
            case Nil      => Assert.assertTrue(false)
        }

    /// The row says which entry ran, and the entry says what it was.
    @Test
    def theRowNamesTheSeasonsEntryRatherThanDescribingIt(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(Some(row#entryId) == Entries.idIn(numbering(), season(), "12"))
            case Nil => Assert.assertTrue(false)
        }

    /// A car the run did not number is a load that wrote the entries and the
    /// cars from different readings of the file.
    @Test
    def aCarTheRunDidNotNumberIsNoRowAtAll(): Unit \ Assert =
        Assert.assertTrue(Option.isEmpty(CarRow.fromRawLaps(
            fujiId(), season(), Entries.noneNumbered(), TestLapRow.sampleLaps())))

    @Test
    def theRowIsBoundInTheOrderTheColumnsAreNamed(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(Cars.values(row)
                    == Value.Integer(7) :: Value.Text("12") :: Value.Integer(row#entryId) :: Nil)
            case Nil => Assert.assertTrue(false)
        }

    /// The reading names every column the load bound, and in that order:
    /// `Db.Cars.all` and `selection` are two orderings of the one declaration,
    /// and no compiler sees them together.
    @Test
    def theReadingNamesTheColumnsTheLoadBound(): Unit \ Assert =
        Assert.assertTrue(
            Sql.toSql(Sql.clause(Cars.selection()))
                == ("SELECT " + List.join(", ", Cars.columnNames()), Nil)
        )

    /// See `Db.TestLapRow`: the type says the key is declared columns, and
    /// this says `all` lists them.
    @Test
    def theKeyNamesColumnsTheTableDeclares(): Unit \ Assert =
        let declared = Cars.columnNames();
        Assert.assertTrue(Cars.primaryKey() |> List.forAll(c -> List.memberOf(c#name, declared)));
        Assert.assertTrue(
            String.contains({substr = "PRIMARY KEY (round_id, car_number)"}, Cars.createTable())
        )

    /// See `Db.TestLapRow`.
    @Test
    def theRowsAreTheKeysTree(): Unit \ Assert =
        let ddl = Cars.createTable();
        Assert.assertTrue(String.endsWith({suffix = ") WITHOUT ROWID"}, ddl));
        Assert.assertTrue(String.contains({substr = "PRIMARY KEY"}, ddl))

    /// A file that describes one car two ways: car 12 is Hertz Team JOTA on
    /// its first lap and AF Corse on its second.
    def contradicting(): List[Motorsport.Wec.RawLap] =
        match TestLapRow.sampleLaps() {
            case first :: second :: rest =>
                first :: { car = { team = "AF Corse" | second#car } | second } :: rest
            case laps => laps
        }

    /// The second description reaches no column, so the load says it or
    /// nothing does.
    @Test
    def whatTheTableDropsIsReported(): Unit \ Assert =
        match CarRow.disagreements(contradicting()) {
            case d :: Nil =>
                Assert.assertTrue(d#carNumber == "12");
                Assert.assertTrue(d#lapNumber == 2);
                Assert.assertTrue(d#field == "team");
                Assert.assertTrue(d#kept == "Hertz Team JOTA");
                Assert.assertTrue(d#found == "AF Corse")
            case _ => Assert.assertTrue(false)
        }

    @Test
    def aFileThatAgreesWithItselfReportsNothing(): Unit \ Assert =
        Assert.assertTrue(List.isEmpty(CarRow.disagreements(TestLapRow.sampleLaps())))

}
