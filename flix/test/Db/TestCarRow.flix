mod Db.TestCarRow {

    use Db.CarRow
    use Db.Cars
    use Db.Manufacturers
    use Db.Numbering
    use Db.Numbering.Numbering
    use Db.Teams
    use Db.TestLapRow
    use Db.Value

    /// The id a run gave the round; see `Db.TestLapRow`.
    def fujiId(): Int32 = 7

    /// The teams and manufacturers the sample names, numbered as a run would
    /// number them.
    def numbered(): (Numbering, Numbering) =
        let cars = CarRow.firstMentions(TestLapRow.sampleLaps());
        let (teams, _) = Teams.add(Numbering.none(), cars |> List.map(c -> c#team));
        let (manufacturers, _) =
            Manufacturers.add(Numbering.none(), cars |> List.map(c -> c#manufacturer));
        (teams, manufacturers)

    /// Two laps of car 12 and one of car 7, in that order.
    def rows(): List[CarRow.CarRow] =
        let (teams, manufacturers) = numbered();
        match CarRow.fromRawLaps(fujiId(), teams, manufacturers, TestLapRow.sampleLaps()) {
            case Some(rows_) => rows_
            case None        => unreachable!()
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

    /// The class and the group are the row's; the team and the manufacturer
    /// are ids into the tables that hold those names.
    @Test
    def theCarIsWhatTheFeedRepeatedOnEveryLapOfIt(): Unit \ Assert =
        let (teams, manufacturers) = numbered();
        match rows() {
            case row :: _ =>
                Assert.assertTrue(row#class == "HYPERCAR");
                Assert.assertTrue(row#carGroup == "H");
                Assert.assertTrue(Teams.idIn(teams, "Hertz Team JOTA") == Some(row#teamId));
                Assert.assertTrue(
                    Manufacturers.idIn(manufacturers, "Porsche") == Some(row#manufacturerId)
                )
            case Nil => Assert.assertTrue(false)
        }

    @Test
    def theRowIsBoundInTheOrderTheColumnsAreNamed(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(Cars.values(row)
                    == Value.Integer(7) :: Value.Text("12") ::
                       Value.Text("HYPERCAR") :: Value.Text("H") ::
                       Value.Integer(1) :: Value.Integer(1) :: Nil)
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
        match CarRow.firstMentions(contradicting()) {
            case car :: _ => Assert.assertTrue(car#team == "Hertz Team JOTA")
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

    /// What the reading gives back is what the writing was handed, the team
    /// and the manufacturer being the tables' rather than the row's.
    @Test
    def aRowMakesTheCarItWasMadeFrom(): Unit \ Assert =
        let (teams, manufacturers) = numbered();
        match rows() {
            case row :: _ =>
                let car = CarRow.toRawCar("Hertz Team JOTA", "Porsche", row);
                Assert.assertTrue(
                    CarRow.fromRawCar(fujiId(), teams, manufacturers, car)
                        |> Option.map(Cars.values)
                        == Some(Cars.values(row))
                )
            case Nil => Assert.assertTrue(false)
        }

}
