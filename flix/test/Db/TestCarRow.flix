mod Db.TestCarRow {

    use Db.CarRow
    use Db.Cars
    use Db.TestLapRow
    use Db.Value
    use Motorsport.Calendar.Entry

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }

    /// Two laps of car 12 and one of car 7, in that order.
    def rows(): List[CarRow.CarRow] =
        CarRow.fromRawLaps(fuji(), TestLapRow.sampleLaps())

    @Test
    def aCarIsOneRowHoweverManyLapsItRan(): Unit \ Assert =
        Assert.assertTrue(List.map(r -> r#carNumber, rows()) == "12" :: "7" :: Nil)

    @Test
    def theRoundIsTheCalendarEntryAndNotTheFeed(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(row#season == 2025);
                Assert.assertTrue(row#round == "fuji_6h")
            case Nil => Assert.assertTrue(false)
        }

    @Test
    def theCarIsWhatTheFeedRepeatedOnEveryLapOfIt(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(row#class == "HYPERCAR");
                Assert.assertTrue(row#carGroup == "H");
                Assert.assertTrue(row#team == "Hertz Team JOTA");
                Assert.assertTrue(row#manufacturer == "Porsche")
            case Nil => Assert.assertTrue(false)
        }

    @Test
    def theRowIsBoundInTheOrderTheColumnsAreNamed(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(Cars.values(row)
                    == Value.Integer(2025) :: Value.Text("fuji_6h") :: Value.Text("12") ::
                       Value.Text("HYPERCAR") :: Value.Text("H") ::
                       Value.Text("Hertz Team JOTA") :: Value.Text("Porsche") :: Nil)
            case Nil => Assert.assertTrue(false)
        }

    /// The reading names every column the load bound, and in that order:
    /// `Db.Cars.all` and `selection` are two orderings of the one declaration,
    /// and no compiler sees them together.
    @Test
    def theReadingNamesTheColumnsTheLoadBound(): Unit \ Assert =
        Assert.assertTrue(
            Sql.toSql(Sql.clause(CarRow.selection()))
                == ("SELECT " + List.join(", ", Cars.columnNames()), Nil)
        )

    @Test
    def theKeyNamesColumnsTheTableHas(): Unit \ Assert =
        let declared = Cars.columnNames();
        Assert.assertTrue(Cars.primaryKey() |> List.forAll(c -> List.memberOf(c#name, declared)));
        Assert.assertTrue(
            String.contains({substr = "PRIMARY KEY (season, round, car_number)"}, Cars.createTable())
        )

    /// What the reading gives back is what the writing was handed.
    @Test
    def aRowMakesTheCarItWasMadeFrom(): Unit \ Assert =
        match rows() {
            case row :: _ =>
                Assert.assertTrue(Cars.values(CarRow.fromRawCar(fuji(), CarRow.toRawCar(row)))
                    == Cars.values(row))
            case Nil => Assert.assertTrue(false)
        }

}
