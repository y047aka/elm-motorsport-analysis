/// The `timeline_events` table: the round's timeline, one row per event.
///
/// Alone among the tables holding what a round did, its rows are the laps
/// counted rather than the file written down. Which of a car's last crossings
/// was the flag and which a retirement is weighed against the time limit, which
/// is `Motorsport.Metadata`'s estimate and no row's, so the load decides it and
/// a reader reads what it decided.
///
/// `seq` orders the events sharing an instant, which nothing else in the row
/// does: a stop ending as the flag falls has to leave the car classified rather
/// than in the pits.
mod Db.TimelineEvents {

    use Db.Rounds
    use Db.Schema
    use Db.Schema.Bound
    use Db.Schema.Column
    use Db.Value
    use Motorsport.Calendar.Entry
    use Motorsport.Timeline
    use Motorsport.Timeline.Event
    use Sql.Sel

    pub def table(): String = "timeline_events"

    pub type alias EventRow = {
        roundId = Int32,
        seq = Int32,
        elapsedMs = Int32,
        event = String,
        carNumber = Option[String],
        lapNumber = Option[Int32],
        durationMs = Option[Int32]
    }

    /// The round's rows. As `Db.Laps.rows`, the pair naming the round is
    /// applied here rather than left to the caller.
    pub def rows(entry: Entry): Sql.Rows[Columns] =
        Sql.access(Sql.raw(table()), columns())
            |> Sql.filter(c -> scope(c, entry))

    pub def primaryKey(): List[Bound[EventRow]] =
        let c = columns();
        Schema.bound(c#roundId) :: Schema.bound(c#seq) :: Nil

    // ---------------------------------------------------------- the events

    pub def fromEvents(roundId: Int32, events: List[Event]): List[EventRow] =
        events
            |> List.zipWithIndex
            |> List.map(match (seq, event) -> row(roundId, seq, event))

    def row(roundId: Int32, seq: Int32, event: Event): EventRow =
        let p = Timeline.parts(event#eventType);
        {
            roundId = roundId,
            seq = seq,
            elapsedMs = Util.Duration.millis(event#elapsed),
            event = p#event,
            carNumber = p#carNumber,
            lapNumber = p#lapNumber,
            durationMs = p#duration |> Option.map(Util.Duration.millis)
        }

    pub def toEvent(r: EventRow): Option[Event] =
        Timeline.eventTypeOf({
            event = r#event,
            carNumber = r#carNumber,
            lapNumber = r#lapNumber,
            duration = r#durationMs |> Option.map(Util.Duration.fromMillis)
        })
            |> Option.map(eventType -> {
                elapsed = Util.Duration.fromMillis(r#elapsedMs),
                eventType = eventType
            })

    // ---------------------------------------------------------- the columns

    pub type alias Columns = {
        roundId = Column[EventRow, Int32],
        seq = Column[EventRow, Int32],
        elapsedMs = Column[EventRow, Int32],
        event = Column[EventRow, String],
        carNumber = Column[EventRow, Option[String]],
        lapNumber = Column[EventRow, Option[Int32]],
        durationMs = Column[EventRow, Option[Int32]]
    }

    /// The three nullable columns are the ones an event may not carry: the
    /// race's own start is nobody's, and only a stop has a lap and a length.
    pub def columns(): Columns = {
        roundId = Schema.integer("round_id", r -> r#roundId),
        seq = Schema.integer("seq", r -> r#seq),
        elapsedMs = Schema.integer("elapsed_ms", r -> r#elapsedMs),
        event = Schema.checkedText("event", Timeline.names(), r -> r#event),
        carNumber = Schema.nullableText("car_number", r -> r#carNumber),
        lapNumber = Schema.nullableInteger("lap_number", r -> r#lapNumber),
        durationMs = Schema.nullableInteger("duration_ms", r -> r#durationMs)
    }

    /// A round's events as the table holds them, a field at a time: each line
    /// names the column and the field its cell lands in, and a field left out
    /// is not an `EventRow`.
    pub def selection(): Sel[EventRow] =
        let c = columns();
        Sql.record({})
            |> Sql.field(c#roundId, (r, value) -> { +roundId = value | r })
            |> Sql.field(c#seq, (r, value) -> { +seq = value | r })
            |> Sql.field(c#elapsedMs, (r, value) -> { +elapsedMs = value | r })
            |> Sql.field(c#event, (r, value) -> { +event = value | r })
            |> Sql.field(c#carNumber, (r, value) -> { +carNumber = value | r })
            |> Sql.field(c#lapNumber, (r, value) -> { +lapNumber = value | r })
            |> Sql.field(c#durationMs, (r, value) -> { +durationMs = value | r })

    /// The order the table declares them in, and so the order the insert binds
    /// them.
    pub def all(): List[Bound[EventRow]] =
        let c = columns();
        Schema.bound(c#roundId) ::
        Schema.bound(c#seq) ::
        Schema.bound(c#elapsedMs) ::
        Schema.bound(c#event) ::
        Schema.bound(c#carNumber) ::
        Schema.bound(c#lapNumber) ::
        Schema.bound(c#durationMs) ::
        Nil

    // --------------------------------------------------------------- schema

    pub def create(): Unit \ DbWrite =
        Schema.recreate(table(), all(), Nil, keys(), storage())

    pub def insertRows(rows_: List[EventRow]): Int32 \ DbWrite =
        Schema.insertRows(table(), all(), rows_)

    pub def values(r: EventRow): List[Value] =
        Schema.values(all(), r)

    /// Taken of the columns the query was handed rather than of this table's
    /// own, so a reading of another source cannot be scoped by them.
    def scope(c: Columns, entry: Entry): Sql.Expr[Bool] =
        Rounds.scope(Schema.qualified(table(), c#roundId), entry)

    pub def createTable(): String =
        Schema.createTable(table(), all(), Nil, keys(), storage())

    def keys(): List[Sql.Key[Bound[EventRow]]] =
        Sql.Key.Primary(primaryKey()) :: Nil

    /// A round's rows are read whole and in one go, so they are the key's tree
    /// and nothing reaches one another way.
    def storage(): Sql.Storage = Sql.Storage.WithoutRowid

    pub def columnNames(): List[String] =
        Schema.columnNames(all())

}
