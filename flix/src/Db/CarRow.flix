mod Db.CarRow {

    use Motorsport.Wec.RawCar
    use Motorsport.Wec.RawLap

    /// One car of one round, which is what the feed repeats on every lap that
    /// car ran: no round in the archive names a car twice, so the file's first
    /// mention of one is the whole of what it says about it.
    pub type alias CarRow = {
        roundId = Int32,
        carNumber = String,
        class = String,
        carGroup = String,
        team = String,
        manufacturer = String
    }

    /// The cars the round's laps name, in the order the file first mentioned
    /// each. A car the file later contradicts itself about keeps what it was
    /// first said to be, which is the same reading the starting grid is
    /// ordered by, and `disagreements` is where the contradiction is said.
    pub def fromRawLaps(roundId: Int32, rawLaps: List[RawLap]): List[CarRow] =
        firstMentions(rawLaps) |> List.map(car -> fromRawCar(roundId, car))

    def firstMentions(rawLaps: List[RawLap]): List[RawCar] =
        let gathered = List.foldLeft((acc, rawLap) -> {
            let number = rawLap#car#carNumber;
            if (Set.memberOf(number, acc#seen))
                acc
            else
                {
                    seen = Set.insert(number, acc#seen),
                    cars = rawLap#car :: acc#cars
                }
        }, { seen = (Set.empty(): Set[String]), cars = (Nil: List[RawCar]) }, rawLaps);
        List.reverse(gathered#cars)

    /// One lap whose car the file described differently from its first
    /// mention: which of the four differs, what the table keeps, and what the
    /// lap said.
    pub type alias Disagreement = {
        carNumber = String,
        lapNumber = Int32,
        field = String,
        kept = String,
        found = String
    }

    /// What the load would otherwise drop without trace. `cars` keeps the
    /// first mention and the second reaches no column, so a file describing
    /// one car two ways is reported here or nowhere. One lap is reported per
    /// car: a description that changes mid-round differs on every lap after
    /// it.
    pub def disagreements(rawLaps: List[RawLap]): List[Disagreement] =
        let kept = firstMentions(rawLaps)
            |> List.map(car -> (car#carNumber, car))
            |> List.toMap;
        let gathered = List.foldLeft((acc, rawLap) -> {
            let number = rawLap#car#carNumber;
            let differing =
                if (Set.memberOf(number, acc#reported))
                    Nil
                else
                    Map.get(number, kept)
                        |> Option.map(first -> differences(first, rawLap#car))
                        |> Option.getWithDefault(Nil);
            if (List.isEmpty(differing))
                acc
            else
                {
                    reported = Set.insert(number, acc#reported),
                    found = List.append(acc#found, differing |> List.map(match (field, was, now) -> {
                        carNumber = number,
                        lapNumber = rawLap#lapNumber,
                        field = field,
                        kept = was,
                        found = now
                    }))
                }
        }, { reported = (Set.empty(): Set[String]), found = (Nil: List[Disagreement]) }, rawLaps);
        gathered#found

    def differences(kept: RawCar, found: RawCar): List[(String, String, String)] =
        let fields =
            ("class", kept#class, found#class) ::
            ("group", kept#group, found#group) ::
            ("team", kept#team, found#team) ::
            ("manufacturer", kept#manufacturer, found#manufacturer) :: Nil;
        fields |> List.filter(match (_, was, now) -> was != now)

    pub def fromRawCar(roundId: Int32, car: RawCar): CarRow =
        {
            roundId = roundId,
            carNumber = car#carNumber,
            class = car#class,
            carGroup = car#group,
            team = car#team,
            manufacturer = car#manufacturer
        }

    pub def toRawCar(row: CarRow): RawCar =
        {
            carNumber    = row#carNumber,
            class        = row#class,
            group        = row#carGroup,
            team         = row#team,
            manufacturer = row#manufacturer
        }

}
