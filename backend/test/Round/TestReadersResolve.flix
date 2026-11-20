/// Every reader of a round, named, sent against the schema the round was created in, and each made to answer with a row: a reader that answers with nothing never runs the projection it reads with.
/// Which statements are written, and what a name that drifted off a table is answered with, is `backend/README.md`'s.
pub mod Round.TestReadersResolve {

    use csv::Csv.Decode
    use csv::Csv.Decode.FieldNames
    use Motorsport.Calendar.Entry
    use Motorsport.Timeline
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Round.TestSupport

    def entry(): Entry =
        { season = 2025, id = "test", date = "2025-01-01" }

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    def decodeOne(csv: String): RawLap =
        match Decode.decodeCustom({fieldSeparator = ';'}, FieldNames.FieldNamesFromFirstRow, Wec.decoder(), csv) {
            case Ok(lap :: _) => lap
            case _            => unreachable!()
        }

    /// The feed's `DRIVER_NUMBER` column, which is what `Round.Timeline.driverChanges` compares -- the name is read by the app, the number by the pipeline.
    def driverNumberOf(name: String): String = match name {
        case "Driver B" => "2"
        case "Driver C" => "3"
        case _          => "1"
    }

    def lap(num: String, driver: String, lapNumber: Int32, lapTime: String, elapsed: String, flag: String, crossing: String, pit: String): RawLap =
        decodeOne(header() + "\n"
            + "${num};${driverNumberOf(driver)};${lapNumber};${lapTime};0;${crossing};20.000;0;20.000;0;20.000;0;100;${elapsed};11:00:00.000;0:20.000;0:20.000;0:20.000;200;${driver};${pit};HYPERCAR;H;Team;Maker;${flag};20.000;20.000;20.000;")

    /// Two cars, three laps each, and one event of every kind the timeline counts: a leader that boxes, a fastest lap, a driver change, and a lead that changes hands on the track.
    /// The car that loses the lead crosses that lap on track, which is what makes the overtake one rather than a car that simply stopped.
    def laps(): List[RawLap] =
        lap("7", "Driver A", 1, "60.000", "1:00.000", "GF", "", "") ::
        lap("8", "Driver B", 1, "62.000", "1:02.000", "GF", "", "") ::
        lap("7", "Driver A", 2, "61.000", "2:01.000", "GF", "B", "10.000") ::
        lap("8", "Driver B", 2, "63.000", "2:03.000", "GF", "", "") ::
        lap("7", "Driver C", 3, "64.000", "3:05.000", "FCY", "", "") ::
        lap("8", "Driver B", 3, "60.500", "3:03.500", "FCY", "", "") ::
        Nil

    /// How many events of one kind the round made.
    ///
    /// A reader that answers with no rows never runs the projection it reads with, so the fixture has to make one event of every kind the timeline counts: the count is what says each of those four readers was sent, answered, and read.
    def countOf(kind: Timeline.CarEvent, events: List[Timeline.Event]): Int32 =
        List.filter(event -> match event#eventType {
            case Timeline.EventType.Of(_, one) => one == kind
            case _                             => false
        }, events) |> List.length

    /// The readers, in the order the round is assembled.
    @Test
    def everyReaderResolvesAgainstTheSchemaItReads(): Unit \ Assert + IO =
        let seen = TestSupport.onRound(entry(), laps(), () -> {
            let seats = Round.Drivers.read(entry());
            let index = Round.Index.read(entry(), seats);
            discard Round.Cars.loaded(entry());
            discard Round.Laps.loaded(entry());
            discard Round.Summary.read(entry(), seats);
            discard Round.Summary.particulars(entry());
            discard Round.Timeline.detailed(entry(), seats, index);
            discard Cli.Load.Validation.detect(entry());
            {
                cars   = Map.size(Round.Cars.read(entry())),
                laps   = List.length(Round.Laps.read(entry(), seats)),
                flags  = List.length(Round.Index.flags(entry())),
                events = Round.Timeline.read(entry())
            }
        });
        let events = seen#events;
        Assert.assertTrue(seen#cars == 2 and seen#laps == 6);
        Assert.assertTrue(seen#flags == 1 and List.length(events) == 9);
        Assert.assertTrue(
            countOf(Timeline.CarEvent.OvertakeForLead, events) >= 1
                and countOf(Timeline.CarEvent.LeaderInPit, events) >= 1
                and countOf(Timeline.CarEvent.FastestLap, events) >= 1
                and countOf(Timeline.CarEvent.DriverChange, events) >= 1)

}
