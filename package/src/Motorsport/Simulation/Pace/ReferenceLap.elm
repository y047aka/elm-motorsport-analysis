module Motorsport.Simulation.Pace.ReferenceLap exposing
    ( ReferenceLap, steady, fromShape
    , timeTo, distanceAfter
    )

{-| How long a reference car takes to reach each distance round a lap: quick along the straights, slow through the bends, braking into them and accelerating out of them.

@docs ReferenceLap, steady, fromShape
@docs timeTo, distanceAfter

-}

import Acceleration exposing (Acceleration)
import Array exposing (Array)
import Duration exposing (Duration)
import Length exposing (Length)
import Motorsport.Circuit.Relief as Relief exposing (Relief)
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Speed exposing (Speed)


type ReferenceLap
    = Steady
    | Profiled
        { step : Float
        , seconds : Array Float
        }


{-| Every metre taken at one metre a second.
-}
steady : ReferenceLap
steady =
    Steady


{-| The reference car's lap of a shape, in the shape's own metres.

A point-mass car limited by how hard it can corner, accelerate and brake, run round the centreline sampled every few metres; every figure it is run with is one of `reference`'s.

    import Duration
    import Length
    import Motorsport.Circuit.Shape as Shape exposing (Shape)

    lap : Shape
    lap =
        Shape.fromMarks
            [ { x = 0, y = 0, metres = 0 }
            , { x = 1000, y = 0, metres = 1000 }
            , { x = 1000, y = 100, metres = 1100 }
            , { x = 0, y = 100, metres = 2100 }
            , { x = 0, y = 0, metres = 2200 }
            ]

    timeTo (fromShape Nothing lap) (Length.meters 0)
    --> Duration.seconds 0

Where the lap's heights are known, the car is slowed climbing and pushed on descending, and brakes harder uphill than down: the slope is read across the same chord as the curvature.

-}
fromShape : Maybe Relief -> Shape -> ReferenceLap
fromShape =
    lapOf reference


lapOf : Parameters -> Maybe Relief -> Shape -> ReferenceLap
lapOf parameters relief shape =
    case readCourse parameters.course relief shape of
        Just reading ->
            runCar (limitsOf parameters.car) reading

        Nothing ->
            Steady


{-| The course as the car is run round it: the lap sampled every `step` metres from the finish line, and at each sample how sharply it bends and how steeply it climbs.
-}
type alias Reading =
    { step : Float
    , samples : List { curvature : Float, slope : Float }
    }


{-| `Nothing` for a lap too short to read a bend off.

A sample's curvature and slope are both read across the chord `curvatureReach` either side of it, and the slope is taken as the slope of the stretch from it to the next.

-}
readCourse : Course -> Maybe Relief -> Shape -> Maybe Reading
readCourse course relief shape =
    let
        lapLength =
            Shape.length shape

        count =
            floor (lapLength / Length.inMeters course.sampleStep)
    in
    if count < 3 then
        Nothing

    else
        let
            step =
                lapLength / toFloat count

            places =
                Array.initialize count (\i -> Shape.at (toFloat i * step) shape)
                    |> Array.map (\{ x, y } -> { x = x, y = y })

            reach =
                max 1 (round (Length.inMeters course.curvatureReach / step))

            slopeAt i =
                case relief of
                    Just heights ->
                        (Relief.at (toFloat (i + reach) * step) heights - Relief.at (toFloat (i - reach) * step) heights)
                            / (toFloat (2 * reach) * step)

                    Nothing ->
                        0
        in
        Just
            { step = step
            , samples =
                List.range 0 (count - 1)
                    |> List.map
                        (\i ->
                            { curvature =
                                Maybe.map3 curvature
                                    (Array.get (modBy count (i - reach)) places)
                                    (Array.get i places)
                                    (Array.get (modBy count (i + reach)) places)
                                    |> Maybe.withDefault 0
                            , slope = slopeAt i
                            }
                        )
            }


runCar : Limits -> Reading -> ReferenceLap
runCar limits { step, samples } =
    let
        speeds =
            samples
                |> List.map (\sample -> { cornering = cornerSpeed limits sample.curvature, slope = sample.slope })
                |> limitByAcceleration limits step
    in
    Profiled { step = step, seconds = Array.fromList (elapsed step speeds) }


{-| Every figure the reference lap is worked out from: how the course is read, and the car that is run round it.
-}
type alias Parameters =
    { course : Course
    , car : Car
    }


{-| How the course's centreline is read.

  - `sampleStep`: how far apart the lap is sampled.
  - `curvatureReach`: how far either side of a sample its curvature and slope are read; the chord this spans smooths the corners OpenStreetMap draws as polygons and stands in for the racing line's wider radius.

-}
type alias Course =
    { sampleStep : Length
    , curvatureReach : Length
    }


{-| The car run round it.

  - `grip`: how hard it can corner standing still. Downforce makes it grip harder the faster it goes, in proportion to the square of its speed, by just enough that a bend wider in radius than `flatOutRadius` is no limit at all.
  - `accelerating`: how hard it can accelerate from a standstill, falling with the square of its speed towards `top`, and never below `leastAcceleration` of it, so that `top` is reached.
  - `braking`: how hard it can brake.
  - `top`: how fast it can go.

-}
type alias Car =
    { grip : Acceleration
    , flatOutRadius : Length
    , accelerating : Acceleration
    , leastAcceleration : Float
    , braking : Acceleration
    , top : Speed
    }


{-| The figures [`fromShape`](#fromShape) runs with.

They are no one car's, and only the shape of the lap is read off them: every lap is stretched to the time it was run in.
The car's were chosen as the figures that share the green-flag laps of the 2025 and 2026 rounds out between the lines the maps give a distance for most nearly as the races did; `RaceShareTest` holds each circuit to its 2026 race.

-}
reference : Parameters
reference =
    { course =
        { sampleStep = Length.meters 5
        , curvatureReach = Length.meters 30
        }
    , car =
        { grip = Acceleration.metersPerSecondSquared 15
        , flatOutRadius = Length.meters 200
        , accelerating = Acceleration.metersPerSecondSquared 10
        , leastAcceleration = 0.02
        , braking = Acceleration.metersPerSecondSquared 20
        , top = Speed.metersPerSecond 92
        }
    }


{-| The car as the passes read it, once per lap, in metres and seconds: a bend of curvature κ is taken at the speed v where v²κ = `grip` + `downforce` v².
-}
type alias Limits =
    { grip : Float
    , downforce : Float
    , accelerating : Float
    , leastAcceleration : Float
    , braking : Float
    , top : Float
    }


limitsOf : Car -> Limits
limitsOf car =
    { grip = Acceleration.inMetersPerSecondSquared car.grip
    , downforce = 1 / Length.inMeters car.flatOutRadius
    , accelerating = Acceleration.inMetersPerSecondSquared car.accelerating
    , leastAcceleration = car.leastAcceleration
    , braking = Acceleration.inMetersPerSecondSquared car.braking
    , top = Speed.inMetersPerSecond car.top
    }


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


cornerSpeed : Limits -> Float -> Float
cornerSpeed limits kappa =
    if kappa > limits.downforce then
        min limits.top (sqrt (limits.grip / (kappa - limits.downforce)))

    else
        limits.top


{-| The cornering speeds, cut to what the car can accelerate up to after each slow point and brake down from before it, in the lap's order.

The lap is a loop, so both passes start at its slowest point, which neither can be going faster than on arrival.

-}
limitByAcceleration : Limits -> Float -> List { cornering : Float, slope : Float } -> List Float
limitByAcceleration limits step samples =
    let
        slowest =
            indexOfSlowest limits samples
    in
    samples
        |> rotate slowest
        |> accelerate limits step
        |> brake limits step
        |> rotate (List.length samples - slowest)


indexOfSlowest : Limits -> List { a | cornering : Float } -> Int
indexOfSlowest limits samples =
    samples
        |> List.indexedMap Tuple.pair
        |> List.foldl
            (\( i, { cornering } ) ( slowestI, slowestSpeed ) ->
                if cornering < slowestSpeed then
                    ( i, cornering )

                else
                    ( slowestI, slowestSpeed )
            )
            ( 0, limits.top )
        |> Tuple.first


{-| The list started `n` places in, and wrapped round to its start.
-}
rotate : Int -> List a -> List a
rotate n list =
    List.drop n list ++ List.take n list


{-| Forwards from the first sample, which is taken at its cornering speed: each sample no faster than the one before it can accelerate to over the slope between them.
-}
accelerate : Limits -> Float -> List { cornering : Float, slope : Float } -> List { speed : Float, slope : Float }
accelerate limits step samples =
    case samples of
        first :: rest ->
            List.foldl
                (\sample ( previous, done ) ->
                    let
                        power =
                            limits.accelerating * max limits.leastAcceleration (1 - (previous.speed / limits.top) ^ 2)

                        reached =
                            { speed = min sample.cornering (reachable step previous.speed (power - gravity * previous.slope))
                            , slope = sample.slope
                            }
                    in
                    ( reached, reached :: done )
                )
                ( { speed = first.cornering, slope = first.slope }, [ { speed = first.cornering, slope = first.slope } ] )
                rest
                |> Tuple.second
                |> List.reverse

        [] ->
            []


{-| Backwards from the last sample, which wraps round to the first: each sample no faster than it can brake from to the one after it over the slope between them.
-}
brake : Limits -> Float -> List { speed : Float, slope : Float } -> List Float
brake limits step samples =
    case samples of
        first :: _ ->
            List.foldr
                (\sample ( next, done ) ->
                    let
                        speed =
                            min sample.speed (reachable step next (limits.braking + gravity * sample.slope))
                    in
                    ( speed, speed :: done )
                )
                ( first.speed, [] )
                samples
                |> Tuple.second

        [] ->
            []


{-| How fast a car going `speed` can be going a step on, changing speed at `acceleration`; never so slow it stops.
-}
reachable : Float -> Float -> Float -> Float
reachable step speed acceleration =
    sqrt (max 1 (speed ^ 2 + 2 * acceleration * step))


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


{-| When the reference car reaches a distance round the lap, from the moment it set off.
A distance past the end of the lap, or short of its start, is on another lap, a lap's time later or earlier.
-}
timeTo : ReferenceLap -> Length -> Duration
timeTo lap along =
    Duration.seconds (secondsAt lap (Length.inMeters along))


{-| How far round the lap the reference car is after a time: the inverse of [`timeTo`](#timeTo).

    import Duration
    import Length

    distanceAfter steady (Duration.seconds 120)
    --> Length.meters 120

-}
distanceAfter : ReferenceLap -> Duration -> Length
distanceAfter lap time =
    Length.meters (metresAt lap (Duration.inSeconds time))


secondsAt : ReferenceLap -> Float -> Float
secondsAt lap metres =
    case lap of
        Steady ->
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


metresAt : ReferenceLap -> Float -> Float
metresAt lap time =
    case lap of
        Steady ->
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
