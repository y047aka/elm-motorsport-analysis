/// The timing feed read without opening it: rows, each class's fastest sector
/// times, the shares those become, the lines those shares place round the lap, and
/// one season's lines laid against another's -- with the columns spelled as the
/// sport spells them. Nothing here reaches a file, a geometry or the network;
/// `TimingLines` hands this the text and prints what it answers, and states
/// the error of the method these readings are subject to.
///
/// `sharesOf` divides a lap the way `Motorsport.Track.ratiosOver` does, written
/// again rather than called: the export's shares are counted by SQL `MIN` over
/// the rows and divided by `Motorsport.Track`, and this division stays
/// independent of the one that wrote them, so a reading here can still report a
/// disagreement with the export rather than only ever agreeing with it.
pub mod TimingLines.Feed {

    use Cli.Errors.CliError
    use Util.Csv.Decode
    use Util.Csv.Decode.Decoder
    use Util.Csv.Decode.FieldNames
    use Util.Duration.Duration

    /// One lap as these readings need it: the class it was run in, and the three
    /// sector times. Neither a blank nor a nought is a time -- the feed writes the
    /// lap it never recorded as `0.000`, and the sectors of such a lap are not
    /// sectors of the circuit.
    pub type alias Row = {
        carClass = String,
        s1 = Option[Duration],
        s2 = Option[Duration],
        s3 = Option[Duration]
    }

    /// A class's fastest through each sector, which is what every class is left
    /// with: one that never crossed one of the lines is refused rather than
    /// carried as a hole in the table.
    pub type alias Times = {
        s1 = Duration,
        s2 = Duration,
        s3 = Duration
    }

    /// One class's fastest, under the name the feed gave it.
    ///
    /// A list in the order the file first showed each class rather than a `Map`,
    /// which would sort them alphabetically: the feed lists the classes in the
    /// order the sport classifies them, Hypercar before LMGT3, and that is the
    /// order the table prints them in.
    pub type alias Fastest = {
        carClass = String,
        times = Times
    }

    /// The field whole, pooled from the classes as the summary's shares are. It
    /// is read as a class and printed as one, and is named so it cannot be
    /// mistaken for one.
    pub def whole(): String = "the round"

    /// The three sectors as the feed spells its columns, which is how the report
    /// names them. Everything below works positionally -- shares, positions and
    /// speeds are each in the order a car drives them -- so only the print needs
    /// the names, and a circuit timed finer than three sectors has nothing here
    /// to say so.
    pub def sectors(): List[String] = List#{"S1", "S2", "S3"}

    /// One line the circuit times to, named as the geometry names it.
    pub type alias Line = {
        id = String,
        metres = Float64
    }

    /// What one circuit's own map of its timing lines amounts to: the lap length
    /// its stretches add up to -- the only claim of theirs a reading may compare
    /// anything against -- and the intermediate lines it puts round it.
    pub type alias CircuitMap = {
        lapLength = Float64,
        lines = List[Line]
    }

    /// Where one class's shares put the map's lines, in the order the map gives
    /// them -- the line the lap is measured from excepted.
    pub type alias Placement = {
        carClass = String,
        positions = List[Float64]
    }

    /// How one season's placements stand against another's. `compared` is signed
    /// -- which way round the lap each line came to stand -- and `furthest` is the
    /// widest of those moves, which is the figure the command judges against the
    /// distance it was allowed.
    pub type alias Movement = {
        compared = List[Placement],
        oneSeasonOnly = List[String],
        furthest = Float64
    }

    // ----------------------------------------------------------------- the feed

    /// The feed's rows, one per lap, from the file's text. `path` names the file
    /// in the messages and is never opened.
    pub def decode(path: String, text: String): Result[CliError, List[Row]] =
        Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            decoder(),
            stripBom(text)
        ) |> Result.mapErr(e -> CliError.Csv({ path = path, message = Decode.errorToString(e) }))

    /// The byte-order mark the timing files lead with, which `Cli.Load.CsvDecode`
    /// strips too: these are two readings of one file, and both have to see the
    /// first column by its name.
    def stripBom(text: String): String =
        if (String.startsWith({prefix = "\uFEFF"}, text)) String.dropLeft(1, text) else text

    /// Only the four columns these readings are about, named rather than counted
    /// out. The load's own `Motorsport.Wec.decoder` reads all twenty-nine, and
    /// reading them here would leave this tool unable to disagree with the export
    /// about anything but the arithmetic.
    pub def decoder(): Decoder[Row] =
        Decode.intoRecord(
            carClass -> s1 -> s2 -> s3 ->
                { carClass = carClass, s1 = s1, s2 = s2, s3 = s3 }
        )
            |> Decode.pipeline(classField())
            |> Decode.pipeline(sectorField("S1"))
            |> Decode.pipeline(sectorField("S2"))
            |> Decode.pipeline(sectorField("S3"))

    def classField(): Decoder[String] =
        Decode.field("CLASS", Decode.string())
            |> Decode.andThen(spelled -> Decode.fromResult(
                if (String.isEmpty(String.trim(spelled)))
                    Err("a lap names no class, so its sectors cannot be the fastest of any.")
                else
                    Ok(String.trim(spelled))
            ))

    def sectorField(name: String): Decoder[Option[Duration]] =
        Decode.field(name, Decode.blank(Decode.string()))
            |> Decode.andThen(spelled -> Decode.fromResult(
                match spelled {
                    case None       => Ok(None)
                    case Some(cell) => readSectorTime(String.trim(cell))
                }
            ))

    def readSectorTime(spelled: String): Result[String, Option[Duration]] =
        match Util.Duration.fromString(spelled) {
            case None       => Err("${spelled} cannot be read as a sector time.")
            case Some(time) => Ok(if (Util.Duration.millis(time) > 0) Some(time) else None)
        }

    /// What each class was fastest at, with the field whole beside them.
    pub def fastestSectors(rows: List[Row]): Result[CliError, List[Fastest]] =
        match rows {
            case Nil => Err(CliError.Reading("the feed holds no laps, so nothing was fastest in any sector."))
            case _   =>
                forM(
                    classes <- Result.traverse(complete, ranThrough(rows));
                    field   <- fieldWhole(classes)
                ) yield classes ++ ({ carClass = whole(), times = field } :: Nil)
        }

    /// Each class's fastest after the laps before it, in the order the file first
    /// showed them.
    type alias Running = {
        carClass = String,
        s1 = Option[Duration],
        s2 = Option[Duration],
        s3 = Option[Duration]
    }

    def ranThrough(rows: List[Row]): List[Running] =
        List.foldLeft(ran, Nil, rows)

    def ran(running: List[Running], row: Row): List[Running] = {
        def faster(held: Running): Running = {
            carClass = held#carClass,
            s1 = fastestOf(held#s1, row#s1),
            s2 = fastestOf(held#s2, row#s2),
            s3 = fastestOf(held#s3, row#s3)
        };

        if (List.exists(holds(row#carClass), running))
            List.map(each -> if (each#carClass == row#carClass) faster(each) else each, running)
        else
            running ++ ({ carClass = row#carClass, s1 = row#s1, s2 = row#s2, s3 = row#s3 } :: Nil)
    }

    def holds(name: String): Running -> Bool = each -> each#carClass == name

    /// A nought is no time, so it never displaces a time; where both classes and
    /// laps are absent the class keeps what it stood at.
    def fastestOf(stood: Option[Duration], time: Option[Duration]): Option[Duration] =
        match (stood, time) {
            case (None, _)          => time
            case (Some(a), Some(b)) => if (Util.Duration.millis(b) < Util.Duration.millis(a)) Some(b) else Some(a)
            case (Some(a), None)    => Some(a)
        }

    /// Every class has to have run every sector: one that has not has no fastest
    /// lap, and every share is counted over the three of them.
    def complete(running: Running): Result[CliError, Fastest] =
        match (running#s1, running#s2, running#s3) {
            case (Some(s1), Some(s2), Some(s3)) =>
                Ok({ carClass = running#carClass, times = { s1 = s1, s2 = s2, s3 = s3 } })
            case _ =>
                Err(CliError.Reading("${running#carClass} recorded no time in every sector."))
        }

    /// The field's own fastest is the fastest of the classes, which is the
    /// reading the summary's shares are counted from.
    def fieldWhole(classes: List[Fastest]): Result[CliError, Times] =
        match (fastestOfSector(firstSector, classes),
               fastestOfSector(secondSector, classes),
               fastestOfSector(thirdSector, classes)) {
            case (Some(s1), Some(s2), Some(s3)) => Ok({ s1 = s1, s2 = s2, s3 = s3 })
            case _                              => Err(CliError.Reading("no class was fastest in every sector."))
        }

    def fastestOfSector(sector: Times -> Duration, classes: List[Fastest]): Option[Duration] =
        List.minimum(List.map(each -> sector(each#times), classes))

    def firstSector(times: Times): Duration = times#s1

    def secondSector(times: Times): Duration = times#s2

    def thirdSector(times: Times): Duration = times#s3

    // -------------------------------------------------------- the circuit's map

    /// The intermediate lines one circuit's published stretches imply, in the
    /// order a car drives them: each stretch ends where the next begins, and the
    /// last ends at the line the lap is measured from -- which is where the lap
    /// started, so it is not a line to place.
    ///
    /// Naming a line is the rule the geometry is written under, which the
    /// survey that writes the geometry follows as well: a line is `s2` because the
    /// second sector begins at it. The atlas reading lays the same lines out of a
    /// kept geometry's own `sectors` and this reading out of the map the report was
    /// given; one rule names them, and no compiler lays the two spellings together.
    ///
    /// The only thing the stretches are trusted with is the lap length they add
    /// up to; where the times place them is `TimingLines`'s question. That
    /// trust is `Circuit.stretchTolerance()`, the same allowance `Midline.sectorLines`
    /// holds them to.
    pub def publishedLines(stretches: List[Float64], lapLength: Float64): Result[CliError, List[Line]] =
        let added = total(stretches);
        if (Float64.abs(added - lapLength) > Circuit.stretchTolerance())
            Err(CliError.Reading("the sectors add up to ${added} m, not the published ${lapLength} m."))
        else
            Ok(List.mapWithIndex(
                (at, ended) -> { id = "s${at + 2}", metres = ended },
                butLast(cumulative(stretches))
            ))

    /// Each sector as a share of the fastest lap the same class could make, in
    /// the order a car drives them: the same three quotients `Motorsport.Track`
    /// divides, written again for the reason in this module's header.
    pub def sharesOf(times: Times): List[Float64] =
        let ran = sectorsOf(times);
        let over = Int32.toFloat64(List.sum(List.map(Util.Duration.millis, ran)));
        List.map(time -> Int32.toFloat64(Util.Duration.millis(time)) / over, ran)

    /// Where round the lap each class's shares put the map's lines.
    pub def impliedLines(fastest: List[Fastest], circuitMap: CircuitMap): List[Placement] =
        List.map(each -> { carClass = each#carClass, positions = placesOf(each#times, circuitMap) }, fastest)

    /// Where round the lap one reading's shares put the map's lines: cumulative
    /// shares read as cumulative distance, short of the whole lap.
    pub def placesOf(times: Times, circuitMap: CircuitMap): List[Float64] =
        let ends = List.take(List.length(circuitMap#lines), cumulative(sharesOf(times)));
        List.map(share -> share * circuitMap#lapLength, ends)

    /// The mean speed over each of the map's stretches, which is what a sector
    /// time taken for a share of the distance hides: km/h to one decimal, as the
    /// table prints it.
    pub def speeds(times: Times, circuitMap: CircuitMap): List[String] =
        let edges = 0.0 :: (List.map(line -> line#metres, circuitMap#lines) ++ (circuitMap#lapLength :: Nil));
        let ground = List.zipWith((begun, ended) -> ended - begun, edges, List.drop(1, edges));
        List.zipWith(
            (metres, time) ->
                fixed(1, metres / (Int32.toFloat64(Util.Duration.millis(time)) / 1000.0) * 3.6),
            ground,
            sectorsOf(times)
        )

    /// How one season's lines stand against another's: every class that ran both
    /// seasons, moved by the same line, and a class that ran one season only --
    /// which has no line to lay against the other's, and is named apart.
    pub def movement(season: List[Placement], against: List[Placement]): Movement = {
        def held(name: String): Option[Placement] = List.find(each -> each#carClass == name, against);

        def moved(each: Placement): Option[Placement] =
            Option.map(
                ran -> { carClass = each#carClass,
                         positions = List.zipWith((ahead, behind) -> ahead - behind, each#positions, ran#positions) },
                held(each#carClass)
            );

        def elsewhere(name: String, other: List[Placement]): Bool =
            List.exists(each -> each#carClass == name, other);

        def apartFrom(other: List[Placement]): Placement -> Option[String] =
            each -> if (elsewhere(each#carClass, other)) None else Some(each#carClass);

        let compared = List.filterMap(moved, season);
        {
            compared = compared,
            oneSeasonOnly = List.filterMap(apartFrom(against), season) ++ List.filterMap(apartFrom(season), against),
            furthest = Option.getWithDefault(
                0.0,
                // Absoluteness is what the distance allowed is compared against, and a
                // line that moved backwards round the lap moved just as far.
                List.maximum(List.map(Float64.abs, List.flatMap(each -> each#positions, compared)))
            )
        }
    }

    // --------------------------------------------------------------- printing

    /// A column: what it is called, and how wide it is held.
    pub type alias Column = {
        name = String,
        width = Int32
    }

    /// One row of a table: each cell padded to its column's width, joined by a
    /// space, and the padding at the end of the row left off.
    pub def table(columns: List[Column], cells: List[String]): String =
        List.zipWith((cell, column) -> String.padRight(column#width, ' ', cell), cells, columns)
            |> List.join(" ")
            |> String.trimRight

    /// A sector time as the sport writes one, which is how the feed wrote it:
    /// `1:06.386`, not a number of seconds.
    pub def seconds(time: Duration): String = Util.Duration.format(time)

    pub def percent(share: Float64): String = "${fixed(2, share * 100.0)}%"

    /// A distance round the lap, to the tenth of a metre the survey is kept at,
    /// and grouped by the thousand as the circuit's own map writes one.
    pub def metres(distance: Float64): String = grouped(fixed(1, distance))

    /// How far round the lap one line moved, with the sign that says which way.
    pub def movedMetres(moved: Float64): String =
        "${if (moved < 0.0) "-" else "+"}${metres(Float64.abs(moved))} m"

    /// A count grouped by the thousand, which is how the five thousand laps of a
    /// round are read off a screen.
    pub def count(laps: Int32): String = grouped("${laps}")

    /// `x` to `places` decimal places, worked out in Int64 because what
    /// `String.format` offers is the running machine's locale: a table whose
    /// decimal separator moves with the machine it was rendered on is no use to a
    /// report that compares one season against another.
    def fixed(places: Int32, x: Float64): String =
        let scale = tenTo(places);
        let scaled = Float64.truncateToInt64(Float64.floor(Float64.abs(x) * Int64.toFloat64(scale) + 0.5));
        let units = Int64.remainder(scaled, scale);
        let sign = if (x < 0.0) "-" else "";
        if (places == 0)
            "${sign}${scaled / scale}"
        else
            "${sign}${scaled / scale}.${String.padLeft(places, '0', Int64.toString(units))}"

    def tenTo(places: Int32): Int64 =
        if (places <= 0) 1i64 else 10i64 * tenTo(places - 1)

    /// The thousands separators in the integer part of a spelled number.
    def grouped(spelled: String): String =
        match String.splitOn({substr = "."}, spelled) {
            case wholePart :: rest =>
                let negative = String.startsWith({prefix = "-"}, wholePart);
                let digits = if (negative) String.dropLeft(1, wholePart) else wholePart;
                let point = match rest {
                    case Nil           => ""
                    case fraction :: _ => ".${fraction}"
                };
                "${if (negative) "-" else ""}${commas(digits)}${point}"
            case Nil => ""
        }

    def commas(digits: String): String =
        if (String.length(digits) <= 3)
            digits
        else
            "${commas(String.dropRight(3, digits))},${String.dropLeft(String.length(digits) - 3, digits)}"

    // ------------------------------------------------------------------ sums

    /// The three sector times in the order a car drives them, which is the order
    /// every list of shares, positions and speeds is in.
    pub def sectorsOf(times: Times): List[Duration] = List#{times#s1, times#s2, times#s3}

    def total(xs: List[Float64]): Float64 = List.foldLeft((acc, x) -> acc + x, 0.0, xs)

    /// Running totals, so each stretch ends where the next one begins.
    def cumulative(xs: List[Float64]): List[Float64] =
        List.drop(1, List.scanLeft((acc, x) -> acc + x, 0.0, xs))

    /// Everything but the last, which is where the last stretch ends -- the line
    /// the lap is measured from, and not a line to place.
    def butLast(xs: List[Float64]): List[Float64] =
        List.reverse(List.drop(1, List.reverse(xs)))

}
