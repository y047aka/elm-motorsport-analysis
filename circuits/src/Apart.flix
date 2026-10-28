/// Laying one line against another: how far a place stands from a line, and the
/// apartness of two such lines. The diff and the atlas reading both sample these.
///
/// Both lines are drawn on one plane — `Geodesy.parallelOf` takes the mean latitude of
/// the two together, so neither is scaled at a rate of its own — and each line's own
/// metres travel with its points, so a line stretched to a published lap length and a
/// line measured at its own are still compared place against place. The sphere, the
/// projection and the metre are `Geodesy`'s; what is here is the sampling.
pub mod Apart {

    use Geodesy.Point
    use Geodesy.hypot
    use Geodesy.zero

    // ------------------------------------------------- the line being sampled against

    /// A stretch of a projected line, and where on the line's own measure each end
    /// stands. A line whose metres run shorter than its points is walked as the points
    /// say, the missing metre being nought — the disagreement `Geometry` refuses a file
    /// for before any of this is asked of it.
    pub type alias Stretch = {
        start  = Point,
        end    = Point,
        metres = Float64,
        after  = Float64
    }

    def stretches(points: List[Point], metres: List[Float64]): List[Stretch] =
        List.range(0, List.length(points) - 1) |> List.map(stretchAt(points, metres))

    def stretchAt(points: List[Point], metres: List[Float64], at: Int32): Stretch = {
        start  = Option.getWithDefault(zero(), List.nth(at, points)),
        end    = Option.getWithDefault(zero(), List.nth(at + 1, points)),
        metres = Option.getWithDefault(0.0, List.nth(at, metres)),
        after  = Option.getWithDefault(0.0, List.nth(at + 1, metres))
    }

    /// A place onto a stretch: how far from it, and how far along the stretch the nearest
    /// place to it stands. A stretch of nought length is a place, and its nearest place
    /// is its own start.
    pub type alias On = {
        distance = Float64,
        at       = Float64
    }

    pub def toSegment(start: Point, end: Point, away: Point): On = {
        let dx = end#x - start#x;
        let dy = end#y - start#y;
        let span = (dx * dx) + (dy * dy);
        let along = if (span == 0.0) 0.0 else clamp((((away#x - start#x) * dx) + ((away#y - start#y) * dy)) / span);
        {
            distance = hypot(start#x + (dx * along) - away#x, start#y + (dy * along) - away#y),
            at       = along
        }
    }

    def clamp(along: Float64): Float64 =
        if (along < 0.0) 0.0 else if (along > 1.0) 1.0 else along

    /// The nearest place on a line, and the metre of the lap it stands at — interpolated
    /// between the stretch's metres, not its start's. Of two stretches equally near, the
    /// first is kept, so a run over the same files says the same thing twice. A line with
    /// no stretch answers `Float64.maxValue()`.
    pub type alias Near = {
        metres   = Float64,
        distance = Float64
    }

    pub def nearestOn(points: List[Point], metres: List[Float64], point: Point): Near =
        Option.getWithDefault(
            {metres = 0.0, distance = Float64.maxValue()},
            nearest(None, List.map(each -> stands(each, point |> toSegment(each#start, each#end)), stretches(points, metres)))
        )

    /// The metre along the lap where the nearest place on a stretch stands.
    def stands(stretch: Stretch, on: On): (On, Float64) =
        (on, stretch#metres + ((stretch#after - stretch#metres) * on#at))

    /// The walk over a line's stretches, keeping the nearest so far.
    def nearest(best: Option[Near], walked: List[(On, Float64)]): Option[Near] =
        match walked {
            case Nil => best
            case one :: rest =>
                let (on, standing) = one;
                let near = {metres = standing, distance = on#distance};
                match best {
                    case None       => nearest(Some(near), rest)
                    case Some(held) => nearest(if (on#distance < held#distance) Some(near) else Some(held), rest)
                }
        }

    // ------------------------------------------------------- one against another

    /// One sampling of a line against another: where on each line's own measure the
    /// nearest place stands, and how far apart they are.
    pub type alias Sample = {
        aMetres  = Float64,
        bMetres  = Float64,
        distance = Float64
    }

    /// How far apart two lines are sampled unless the reader names another spacing:
    /// corners stand tens of metres apart and the apartness is a slow wave along a lap.
    pub def defaultEvery(): Float64 = 25.0

    /// The reading of two lines: how many places were sampled, the mean apartness, and
    /// the worst of them, with the place it was found at on each line's own measure.
    pub type alias Apartness = {
        count = Int32,
        mean  = Float64,
        worst = Sample
    }

    /// The first line laid against the second, sampled every `every` metres along the
    /// first. The end of the sampled line is not itself sampled — the walk stops short
    /// of it, which is what `count` says.
    pub def apartness(
        aPoints: List[Point],
        aMetres: List[Float64],
        bPoints: List[Point],
        bMetres: List[Float64],
        every: Float64
    ): Result[String, Apartness] =
        let length = lastMetre(aMetres);
        if (length <= 0.0)
            Err("nothing is measured along the sampled line: its own metres end at ${Util.Format.spelled(length)} m")
        else
            Ok(readings(samples(0.0, length, every, aPoints, aMetres, bPoints, bMetres)))

    def lastMetre(metres: List[Float64]): Float64 =
        Option.getWithDefault(0.0, List.last(metres))

    def samples(
        at: Float64,
        length: Float64,
        every: Float64,
        aPoints: List[Point],
        aMetres: List[Float64],
        bPoints: List[Point],
        bMetres: List[Float64]
    ): List[Sample] =
        if (at >= length)
            Nil
        else {
            let near = at |> interpolate(aPoints, aMetres) |> nearestOn(bPoints, bMetres);
            {aMetres = at, bMetres = near#metres, distance = near#distance} :: samples(at + every, length, every, aPoints, aMetres, bPoints, bMetres)
        }

    /// The mean, and the worst of what was sampled — the first place the readings tie at.
    def readings(sampled: List[Sample]): Apartness = {
        let total = List.foldLeft((sum, each) -> sum + each#distance, 0.0, sampled);
        {
            count = List.length(sampled),
            mean  = total / Int32.toFloat64(List.length(sampled)),
            worst = worstOf(sampled)
        }
    }

    def worstOf(sampled: List[Sample]): Sample =
        match sampled {
            case first :: rest => List.foldLeft((held, each) -> if (each#distance > held#distance) each else held, first, rest)
            case Nil           => {aMetres = 0.0, bMetres = 0.0, distance = 0.0}
        }

    /// The place `s` metres along a line, walked by the line's own metres: the first
    /// stretch whose end is no longer short of it, the last stretch excepted, which is
    /// where a place beyond the line's end falls. A stretch of nought length is walked
    /// through rather than divided by.
    pub def interpolate(points: List[Point], metres: List[Float64], s: Float64): Point =
        if (List.length(points) < 2)
            zero()
        else
            walk(points, metres, s, 1, List.length(metres) - 2)

    def walk(points: List[Point], metres: List[Float64], s: Float64, at: Int32, last: Int32): Point =
        match (List.nth(at - 1, points), List.nth(at, points), List.nth(at - 1, metres), List.nth(at, metres)) {
            case (Some(before), Some(after), Some(short), Some(far)) =>
                if (at <= last and far < s)
                    walk(points, metres, s, at + 1, last)
                else
                    stretched(before, after, short, far, s)
            case _ => zero()
        }

    def stretched(before: Point, after: Point, short: Float64, far: Float64, s: Float64): Point = {
        let span = far - short;
        let along = if (span == 0.0) 0.0 else (s - short) / span;
        {
            x = before#x + ((after#x - before#x) * along),
            y = before#y + ((after#y - before#y) * along)
        }
    }
}
