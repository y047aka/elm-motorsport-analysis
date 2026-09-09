mod Db.TestEntries {

    use Db.CarRow
    use Db.Entries
    use Db.TestLapRow
    use Db.Value

    def season(): Int32 = 2025

    def cars(): List[Motorsport.Wec.RawCar] =
        CarRow.firstMentions(TestLapRow.sampleLaps())

    def numbered(): (Entries.Numbering, List[Entries.EntryRow], List[Entries.Disagreement]) =
        Entries.add(Entries.noneNumbered(), season(), cars())

    @Test
    def anEntryIsOneRowHoweverManyRoundsItRan(): Unit \ Assert =
        let (numbering, added, _) = numbered();
        Assert.assertTrue(List.map(r -> r#carNumber, added) == "12" :: "7" :: Nil);
        let (again, more, _) = Entries.add(numbering, season(), cars());
        Assert.assertTrue(List.isEmpty(more));
        Assert.assertTrue(Map.size(again) == 2)

    @Test
    def theEntryIsWhatTheFeedRepeatedOnEveryLapOfIt(): Unit \ Assert =
        match numbered() {
            case (_, row :: _, _) =>
                Assert.assertTrue(row#season == season());
                Assert.assertTrue(row#class == "HYPERCAR");
                Assert.assertTrue(row#carGroup == Some("H"));
                Assert.assertTrue(row#team == "Hertz Team JOTA");
                Assert.assertTrue(row#manufacturer == "Porsche")
            case _ => Assert.assertTrue(false)
        }

    /// A car number is an entry within its season and a different one across
    /// seasons, so the same number numbered under two of them is two rows.
    @Test
    def aCarNumberIsAnEntryOfItsSeasonAndNotOfTheArchive(): Unit \ Assert =
        let (numbering, _, _) = numbered();
        let (both, added, differing) = Entries.add(numbering, 2026, cars());
        Assert.assertTrue(List.length(added) == 2);
        Assert.assertTrue(List.isEmpty(differing));
        Assert.assertTrue(Map.size(both) == 4);
        Assert.assertTrue(Entries.idIn(both, season(), "12") != Entries.idIn(both, 2026, "12"))

    /// The feed spells a car with no sub-class as one whose group is empty,
    /// and the round trip back to the feed's spelling is what the summary
    /// reads.
    @Test
    def aCarWithNoSubClassHasNoGroupRatherThanAnEmptyOne(): Unit \ Assert =
        let plain = { carNumber = "9", class = "LMGT3", group = "",
                      team = "Iron Lynx", manufacturer = "Mercedes-AMG" };
        match Entries.add(Entries.noneNumbered(), season(), plain :: Nil) {
            case (_, row :: Nil, _) =>
                Assert.assertTrue(row#carGroup == None);
                Assert.assertTrue(Entries.toRawCar(row)#group == "")
            case _ => Assert.assertTrue(false)
        }

    /// Car 12 is Porsche in the round that first named it and Mercedes in a
    /// later one, which is the archive's own shape: the same car of the same
    /// season is spelled two ways across the rounds it ran.
    @Test
    def aLaterRoundDescribingAnEntryOtherwiseIsReported(): Unit \ Assert =
        let (numbering, _, _) = numbered();
        let renamed = cars() |> List.map(car ->
            if (car#carNumber == "12") { manufacturer = "Mercedes" | car } else car);
        match Entries.add(numbering, season(), renamed) {
            case (_, added, d :: Nil) =>
                Assert.assertTrue(List.isEmpty(added));
                Assert.assertTrue(d#season == season());
                Assert.assertTrue(d#carNumber == "12");
                Assert.assertTrue(d#field == "manufacturer");
                Assert.assertTrue(d#kept == "Porsche");
                Assert.assertTrue(d#found == "Mercedes")
            case _ => Assert.assertTrue(false)
        }

    @Test
    def aSeasonThatAgreesWithItselfReportsNothing(): Unit \ Assert =
        let (numbering, _, _) = numbered();
        let (_, _, differing) = Entries.add(numbering, season(), cars());
        Assert.assertTrue(List.isEmpty(differing))

    @Test
    def theRowIsBoundInTheOrderTheColumnsAreNamed(): Unit \ Assert =
        Assert.assertTrue(
            Entries.values({ entryId = 3, season = 2025, carNumber = "7", class = "HYPERCAR",
                             carGroup = None, team = "Toyota Gazoo Racing", manufacturer = "Toyota" })
                == Value.Integer(3) :: Value.Integer(2025) :: Value.Text("7") ::
                   Value.Text("HYPERCAR") :: Value.NullableText(None) ::
                   Value.Text("Toyota Gazoo Racing") :: Value.Text("Toyota") :: Nil
        )

    /// The reading names every column the load bound, and in that order:
    /// `Db.Entries.all` and `selection` are two orderings of the one
    /// declaration, and no compiler sees them together.
    @Test
    def theReadingNamesTheColumnsTheLoadBound(): Unit \ Assert =
        Assert.assertTrue(
            Sql.toSql(Sql.clause(Entries.selection()))
                == ("SELECT " + List.join(", ", Entries.columnNames()), Nil)
        )

    @Test
    def theKeysNameColumnsTheTableDeclares(): Unit \ Assert =
        let declared = Entries.columnNames();
        Assert.assertTrue(
            List.append(Entries.primaryKey(), Entries.seasonKey())
                |> List.forAll(c -> List.memberOf(c#name, declared))
        );
        let ddl = Entries.createTable();
        Assert.assertTrue(String.contains({substr = "PRIMARY KEY (entry_id)"}, ddl));
        Assert.assertTrue(String.contains({substr = "UNIQUE (season, car_number)"}, ddl));
        Assert.assertTrue(String.contains({substr = "car_group text,"}, ddl))

}
