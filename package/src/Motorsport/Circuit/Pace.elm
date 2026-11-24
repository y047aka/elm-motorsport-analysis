module Motorsport.Circuit.Pace exposing
    ( Pace, even, fromShape
    , secondsAt, metresAt
    )

{-| How long a reference car takes to reach each distance round a lap: quick along the straights, slow through the bends, braking into them and accelerating out of them.

A lap's timing says only when a car crossed each line; between two lines the tracker spends the time the car took there as this reference spends it, so the car still crosses every line when its timing says it did.

@docs Pace, even, fromShape
@docs secondsAt, metresAt

-}

import Array exposing (Array)
import Motorsport.Circuit.Relief as Relief exposing (Relief)
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)


type Pace
    = Even
    | Profiled
        { step : Float
        , seconds : Array Float
        }


{-| Every metre taken at one speed: a second is a metre.
-}
even : Pace
even =
    Even


{-| The reference car's lap of a shape, in the shape's own metres.

A point-mass car limited by how hard it can corner, accelerate and brake, run round the centreline sampled every few metres.
The curvature is read across a chord 60 m long, which smooths the corners OpenStreetMap draws as polygons and stands in for the racing line's wider radius.

The limits are no one car's.
They were chosen against Le Mans 2025, where they put the seven lines its map gives a distance for at their share of the lap to within 0.03 of the lap in all, against 0.09 for an even pace (`LeMansPaceTest`).
Only the shape of the lap is read off them: every lap is stretched to the time it was run in.

    lap : Shape
    lap =
        Shape.fromMarks
            [ { x = 0, y = 0, metres = 0 }
            , { x = 1000, y = 0, metres = 1000 }
            , { x = 1000, y = 100, metres = 1100 }
            , { x = 0, y = 100, metres = 2100 }
            , { x = 0, y = 0, metres = 2200 }
            ]

    secondsAt (fromShape Nothing lap) 0
    --> 0

Where the lap's heights are known, the car is slowed climbing and pushed on descending, and brakes harder uphill than down: the slope is read across the same 60 m chord.

-}
fromShape : Maybe Relief -> Shape -> Pace
fromShape relief shape =
    let
        lapLength =
            Shape.length shape

        count =
            floor (lapLength / sampleStep)
    in
    if count < 3 then
        Even

    else
        let
            step =
                lapLength / toFloat count

            places =
                Array.initialize count (\i -> Shape.at (toFloat i * step) shape)
                    |> Array.map (\{ x, y } -> { x = x, y = y })

            reach =
                max 1 (round (curvatureReach / step))

            gradeAt i =
                case relief of
                    Just heights ->
                        (Relief.at (toFloat (i + reach) * step) heights - Relief.at (toFloat (i - reach) * step) heights)
                            / (toFloat (2 * reach) * step)

                    Nothing ->
                        0

            samples =
                List.range 0 (count - 1)
                    |> List.map
                        (\i ->
                            { cornering =
                                Maybe.map3 curvature
                                    (Array.get (modBy count (i - reach)) places)
                                    (Array.get i places)
                                    (Array.get (modBy count (i + reach)) places)
                                    |> Maybe.withDefault 0
                                    |> cornerSpeed
                            , grade = gradeAt i
                            }
                        )

            speeds =
                limitByAcceleration step samples
        in
        Profiled { step = step, seconds = Array.fromList (elapsed step speeds) }


sampleStep : Float
sampleStep =
    5


curvatureReach : Float
curvatureReach =
    30


{-| Metres per second squared, and metres per second.
-}
limits : { lateral : Float, accelerating : Float, braking : Float, top : Float }
limits =
    { lateral = 30, accelerating = 10, braking = 30, top = 92 }


{-| The curvature of the circle through three points, from the area of the triangle they make.
-}
curvature : Point -> Point -> Point -> Float
curvature a b c =
    let
        twiceArea =
            abs ((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))

        sides =
            distance a b * distance b c * distance a c
    in
    if sides > 0 then
        2 * twiceArea / sides

    else
        0


distance : Point -> Point -> Float
distance a b =
    sqrt ((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)


cornerSpeed : Float -> Float
cornerSpeed kappa =
    if kappa > 0 then
        min limits.top (sqrt (limits.lateral / kappa))

    else
        limits.top


{-| The cornering speeds, cut to what the car can accelerate up to after each slow point and brake down from before it.

The lap is a loop, so both passes start at its slowest point, which neither can be going faster than on arrival.
A sample's grade is the slope across the chord centred on it, taken as the slope of the stretch from it to the next.

-}
limitByAcceleration : Float -> List { cornering : Float, grade : Float } -> List Float
limitByAcceleration step samples =
    let
        count =
            List.length samples

        slowest =
            samples
                |> List.indexedMap Tuple.pair
                |> List.foldl
                    (\( i, { cornering } ) ( bestI, bestV ) ->
                        if cornering < bestV then
                            ( i, cornering )

                        else
                            ( bestI, bestV )
                    )
                    ( 0, limits.top )
                |> Tuple.first

        rotated =
            List.drop slowest samples ++ List.take slowest samples

        reachable speed acceleration =
            sqrt (max 1 (speed ^ 2 + 2 * acceleration * step))

        accelerated =
            case rotated of
                first :: rest ->
                    List.foldl
                        (\sample ( previous, done ) ->
                            let
                                power =
                                    limits.accelerating * max 0.02 (1 - (previous.speed / limits.top) ^ 2)

                                speed =
                                    min sample.cornering (reachable previous.speed (power - gravity * previous.grade))
                            in
                            ( { speed = speed, grade = sample.grade }, { speed = speed, grade = sample.grade } :: done )
                        )
                        ( { speed = first.cornering, grade = first.grade }, [ { speed = first.cornering, grade = first.grade } ] )
                        rest
                        |> Tuple.second

                [] ->
                    []

        braked =
            case List.reverse accelerated of
                first :: _ ->
                    List.foldl
                        (\sample ( next, done ) ->
                            let
                                speed =
                                    min sample.speed (reachable next (limits.braking + gravity * sample.grade))
                            in
                            ( speed, speed :: done )
                        )
                        ( first.speed, [] )
                        accelerated
                        |> Tuple.second

                [] ->
                    []
    in
    List.drop (count - slowest) braked ++ List.take (count - slowest) braked


gravity : Float
gravity =
    9.81


{-| The time each sample is reached at, from the first, and the whole lap's last.
-}
elapsed : Float -> List Float -> List Float
elapsed step speeds =
    case speeds of
        first :: _ ->
            List.map2 (\a b -> step * 2 / (a + b)) speeds (List.drop 1 speeds ++ [ first ])
                |> List.foldl (\dt ( t, done ) -> ( t + dt, (t + dt) :: done )) ( 0, [ 0 ] )
                |> Tuple.second
                |> List.reverse

        [] ->
            [ 0 ]


{-| When the reference car reaches a distance round the lap.
A distance past the end of the lap, or short of its start, is on another lap, a lap's time later or earlier.
-}
secondsAt : Pace -> Float -> Float
secondsAt pace metres =
    case pace of
        Even ->
            metres

        Profiled { step, seconds } ->
            let
                count =
                    Array.length seconds - 1

                lapLength =
                    step * toFloat count

                laps =
                    toFloat (floor (metres / lapLength))

                within =
                    (metres - laps * lapLength) / step

                i =
                    clamp 0 (count - 1) (floor within)

                lapSeconds =
                    get count seconds
            in
            laps * lapSeconds + lerp (get i seconds) (get (i + 1) seconds) (within - toFloat i)


{-| How far round the lap the reference car is after a time: the inverse of [`secondsAt`](#secondsAt).

    metresAt even 120
    --> 120

-}
metresAt : Pace -> Float -> Float
metresAt pace time =
    case pace of
        Even ->
            time

        Profiled { step, seconds } ->
            let
                count =
                    Array.length seconds - 1

                lapSeconds =
                    get count seconds

                laps =
                    toFloat (floor (time / lapSeconds))

                within =
                    time - laps * lapSeconds

                i =
                    lastAtOrBefore within seconds 0 count

                from =
                    get i seconds

                to =
                    get (i + 1) seconds

                fraction =
                    if to > from then
                        (within - from) / (to - from)

                    else
                        0
            in
            step * (laps * toFloat count + toFloat i + fraction)


lastAtOrBefore : Float -> Array Float -> Int -> Int -> Int
lastAtOrBefore time seconds lo hi =
    if hi - lo <= 1 then
        lo

    else
        let
            mid =
                (lo + hi) // 2
        in
        if get mid seconds <= time then
            lastAtOrBefore time seconds mid hi

        else
            lastAtOrBefore time seconds lo mid


get : Int -> Array Float -> Float
get i array =
    Array.get i array |> Maybe.withDefault 0


lerp : Float -> Float -> Float -> Float
lerp a b fraction =
    a + fraction * (b - a)
