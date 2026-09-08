mod Db.TestCarDrivers {

    use Db.CarDrivers
    use Db.Drivers
    use Db.TestLapRow
    use Db.Value
    use Motorsport.Wec.RawLap

    def roundId(): Int32 = 7

    /// The fuji sample: car 12 in seats 1 and 2, then car 7 in seat 1.
    def seats(): List[CarDrivers.Seat] =
        CarDrivers.seats(TestLapRow.sampleLaps())

    @Test
    def aSeatIsOneRowHoweverManyLapsItRan(): Unit \ Assert =
        Assert.assertTrue(
            seats() |> List.map(s -> (s#carNumber, s#driverNumber, s#name))
                == ("12", 1, "Will STEVENS") :: ("12", 2, "Robin FRIJNS") ::
                   ("7", 1, "Kamui KOBAYASHI") :: Nil
        )

    /// A name the run has already numbered keeps its number, so a driver who
    /// turns up in a second round is the same row.
    @Test
    def aNameIsNumberedOnceHoweverManyRoundsNameIt(): Unit \ Assert =
        let (first, addedFirst) = Drivers.add(Drivers.noneNumbered(), "A" :: "B" :: "A" :: Nil);
        Assert.assertTrue(List.map(r -> (r#driverId, r#name), addedFirst)
            == (1, "A") :: (2, "B") :: Nil);
        let (second, addedSecond) = Drivers.add(first, "B" :: "C" :: Nil);
        Assert.assertTrue(List.map(r -> (r#driverId, r#name), addedSecond) == (3, "C") :: Nil);
        Assert.assertTrue(Drivers.idIn(second, "A") == Some(1));
        Assert.assertTrue(Drivers.idIn(second, "D") == None)

    @Test
    def aSeatTakesTheIdItsNameWasGiven(): Unit \ Assert =
        let (numbering, _) = Drivers.add(Drivers.noneNumbered(), seats() |> List.map(s -> s#name));
        match CarDrivers.fromSeats(roundId(), numbering, seats()) {
            case None       => Assert.assertTrue(false)
            case Some(rows) =>
                Assert.assertTrue(List.map(r -> (r#carNumber, r#driverNumber, r#driverId), rows)
                    == ("12", 1, 1) :: ("12", 2, 2) :: ("7", 1, 3) :: Nil);
                Assert.assertTrue(List.forAll(r -> r#roundId == roundId(), rows))
        }

    /// A name the run did not number is a load that read the file twice and
    /// differently, which is the one thing these rows cannot be built from.
    @Test
    def aSeatWhoseNameIsNotNumberedIsNoRows(): Unit \ Assert =
        Assert.assertTrue(
            Option.isEmpty(CarDrivers.fromSeats(roundId(), Drivers.noneNumbered(), seats()))
        )

    /// A file that names one seat two ways: car 12's seat 1 is Will STEVENS on
    /// its first lap and someone else on a later one.
    def contradicting(): List[RawLap] =
        match TestLapRow.sampleLaps() {
            case first :: second :: rest =>
                first :: { driver = { number = 1, name = "Nyck DE VRIES" } | second } :: rest
            case laps => laps
        }

    @Test
    def aSeatKeepsWhatTheFileFirstCalledIt(): Unit \ Assert =
        match CarDrivers.seats(contradicting()) {
            case seat :: _ => Assert.assertTrue(seat#name == "Will STEVENS")
            case Nil       => Assert.assertTrue(false)
        }

    /// The second name reaches no column, so the load says it or nothing does.
    @Test
    def whatTheTableDropsIsReported(): Unit \ Assert =
        match CarDrivers.disagreements(contradicting()) {
            case d :: Nil =>
                Assert.assertTrue(d#carNumber == "12");
                Assert.assertTrue(d#driverNumber == 1);
                Assert.assertTrue(d#lapNumber == 2);
                Assert.assertTrue(d#kept == "Will STEVENS");
                Assert.assertTrue(d#found == "Nyck DE VRIES")
            case _ => Assert.assertTrue(false)
        }

    @Test
    def aFileThatAgreesWithItselfReportsNothing(): Unit \ Assert =
        Assert.assertTrue(List.isEmpty(CarDrivers.disagreements(TestLapRow.sampleLaps())))

    // ------------------------------------------------------------ the schema

    @Test
    def theKeysNameColumnsTheTablesDeclare(): Unit \ Assert =
        Assert.assertTrue(
            CarDrivers.primaryKey()
                |> List.forAll(c -> List.memberOf(c#name, CarDrivers.columnNames()))
        );
        Assert.assertTrue(String.contains(
            {substr = "PRIMARY KEY (round_id, car_number, driver_number)"},
            CarDrivers.createTable()
        ));
        Assert.assertTrue(String.contains({substr = "PRIMARY KEY (driver_id)"}, Drivers.createTable()));
        Assert.assertTrue(String.contains({substr = "UNIQUE (name)"}, Drivers.createTable()))

    @Test
    def theRowIsBoundInTheOrderTheColumnsAreNamed(): Unit \ Assert =
        Assert.assertTrue(
            CarDrivers.values({ roundId = 7, carNumber = "12", driverNumber = 2, driverId = 5 })
                == Value.Integer(7) :: Value.Text("12") :: Value.Integer(2) :: Value.Integer(5) :: Nil
        );
        Assert.assertTrue(
            Drivers.values({ driverId = 5, name = "Will STEVENS" })
                == Value.Integer(5) :: Value.Text("Will STEVENS") :: Nil
        )

}
