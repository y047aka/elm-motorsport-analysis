mod Db.TestCarRow {

    use Db.CarRow
    use Db.Cars
    use Db.TestLapRow
    use Db.Value

    /// The id a run gave the round; see `Db.TestLapRow`.
    def fujiId(): Int32 = 7

    /// Two laps of car 12 and one of car 7, in that order.
    def rows(): List[CarRow.CarRow] =
        CarRow.fromRawLaps(fujiId(), TestLapRow.sampleLaps())

    @Test
    def aCarIsOneRowHoweverManyLapsItRan(): Unit \ Assert =
        Assert.assertTrue(List.map(r -> r#carNumber, rows()) == "12" :: "7" :: Nil)

    @Test
    def theRoundIsTheOneTheLoadNamedAndNotTheFeed(): Unit \ Assert =
        match rows() {
            case row :: _ => Assert.assertTrue(row#roundId == fujiId())
            case Nil      => Assert.assertTrue(false)
        }

    @Test
    def theCarIsWhatTheFeedRepeatedOnEveryLapOfIt(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(row#class == "HYPERCAR");
                Assert.assertTrue(row#carGroup == Some("H"));
                Assert.assertTrue(row#team == "Hertz Team JOTA");
                Assert.assertTrue(row#manufacturer == "Porsche")
            case Nil => Assert.assertTrue(false)
        }

    /// The feed spells a car with no sub-class as one whose group is empty,
    /// and the round trip back to the feed's spelling is what the summary
    /// reads.
    @Test
    def aCarWithNoSubClassHasNoGroupRatherThanAnEmptyOne(): Unit \ Assert =
        let plain = CarRow.fromRawCar(fujiId(), { carNumber = "9", class = "LMGT3",
            group = "", team = "Iron Lynx", manufacturer = "Mercedes-AMG" });
        Assert.assertTrue(plain#carGroup == None);
        Assert.assertTrue(CarRow.toRawCar(plain)#group == "");
        Assert.assertTrue(String.contains({substr = "car_group text,"}, Cars.createTable()))

    @Test
    def theRowIsBoundInTheOrderTheColumnsAreNamed(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(Cars.values(row)
                    == Value.Integer(7) :: Value.Text("12") ::
                       Value.Text("HYPERCAR") :: Value.NullableText(Some("H")) ::
                       Value.Text("Hertz Team JOTA") :: Value.Text("Porsche") :: Nil)
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

    @Test
    def aCarKeepsWhatTheFileFirstSaidItWas(): Unit \ Assert =
        match CarRow.fromRawLaps(fujiId(), contradicting()) {
            case row :: _ => Assert.assertTrue(row#team == "Hertz Team JOTA")
            case Nil      => Assert.assertTrue(false)
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

    /// What the reading gives back is what the writing was handed.
    @Test
    def aRowMakesTheCarItWasMadeFrom(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(Cars.values(CarRow.fromRawCar(fujiId(), CarRow.toRawCar(row)))
                    == Cars.values(row))
            case Nil => Assert.assertTrue(false)
        }

}
