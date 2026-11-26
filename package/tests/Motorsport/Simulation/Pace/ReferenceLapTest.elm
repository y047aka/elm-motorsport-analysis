module Motorsport.Simulation.Pace.ReferenceLapTest exposing (stadium, tests)

import Duration
import Expect
import Length
import Motorsport.Circuit.Relief as Relief exposing (Relief)
import Motorsport.Circuit.Shape as Shape exposing (Shape)
import Motorsport.Simulation.Pace.ReferenceLap as ReferenceLap exposing (ReferenceLap)
import Test exposing (Test, describe, test)


{-| Two straights 1,000 m long joined by two half circles of 50 m radius, run from the start of the lower straight: the first bend runs from 1,000 m to about 1,157 m.
-}
stadium : Shape
stadium =
    let
        radius =
            50

        bendLength =
            pi * radius

        bend centreX fromAngle startMetres =
            List.range 1 18
                |> List.map
                    (\i ->
                        let
                            angle =
                                fromAngle + pi * toFloat i / 18
                        in
                        { x = centreX + radius * cos angle
                        , y = radius + radius * sin angle
                        , metres = startMetres + bendLength * toFloat i / 18
                        }
                    )
    in
    Shape.fromMarks
        ({ x = 0, y = 0, metres = 0 }
            :: { x = 1000, y = 0, metres = 1000 }
            :: bend 1000 (-pi / 2) 1000
            ++ { x = 0, y = 2 * radius, metres = 2000 + bendLength }
            :: bend 0 (pi / 2) (2000 + bendLength)
        )


{-| The stadium on a slope: the lower straight climbs 50 m and the upper one comes back down.
-}
hill : Relief
hill =
    Relief.fromHeights
        { lap =
            [ { metres = 0, height = 0 }
            , { metres = 1000, height = 50 }
            , { metres = 1000 + pi * 50, height = 50 }
            , { metres = 2000 + pi * 50, height = 0 }
            , { metres = Shape.length stadium, height = 0 }
            ]
        , pitLane = []
        }


pace : ReferenceLap
pace =
    ReferenceLap.fromShape Nothing stadium


{-| Seconds per metre over the ten metres from a distance.
-}
slowness : Float -> Float
slowness =
    slownessOf pace


slownessOf : ReferenceLap -> Float -> Float
slownessOf of_ metres =
    (secondsAt of_ (metres + 10) - secondsAt of_ metres) / 10


secondsAt : ReferenceLap -> Float -> Float
secondsAt of_ metres =
    Duration.inSeconds (ReferenceLap.timeTo of_ (Length.meters metres))


tests : Test
tests =
    describe "Motorsport.Simulation.Pace.ReferenceLap"
        [ test "a bend is taken slower than a straight" <|
            \_ ->
                slowness 1070
                    |> Expect.greaterThan (slowness 500)
        , test "the car brakes before a bend" <|
            \_ ->
                slowness 980
                    |> Expect.greaterThan (slowness 800)
        , test "the car accelerates out of a bend" <|
            \_ ->
                slowness 1700
                    |> Expect.greaterThan (slowness 1900)
        , test "a climb is taken slower than the same straight on the level" <|
            \_ ->
                slownessOf (ReferenceLap.fromShape (Just hill) stadium) 800
                    |> Expect.greaterThan (slowness 800)
        , test "a descent is taken quicker than the same straight on the level" <|
            \_ ->
                slownessOf (ReferenceLap.fromShape (Just hill) stadium) 1500
                    |> Expect.lessThan (slowness 1500)
        , test "distanceAfter undoes timeTo" <|
            \_ ->
                [ 0, 123, 1000, 1080, 2300 ]
                    |> List.map (Length.meters >> ReferenceLap.timeTo pace >> ReferenceLap.distanceAfter pace >> Length.inMeters)
                    |> List.map2 (\expected actual -> abs (expected - actual)) [ 0, 123, 1000, 1080, 2300 ]
                    |> List.maximum
                    |> Maybe.withDefault 0
                    |> Expect.atMost 0.001
        , test "a distance a lap on is reached a lap's time later" <|
            \_ ->
                secondsAt pace (Shape.length stadium + 300)
                    |> Expect.within (Expect.Absolute 0.001)
                        (secondsAt pace (Shape.length stadium) + secondsAt pace 300)
        , test "a steady lap takes a second over each metre" <|
            \_ ->
                ReferenceLap.timeTo ReferenceLap.steady (Length.meters 1234)
                    |> Expect.equal (Duration.seconds 1234)
        ]
