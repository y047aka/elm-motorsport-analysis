module Motorsport.Circuit.PaceTest exposing (stadium, tests)

import Expect
import Motorsport.Circuit.Pace as Pace exposing (Pace)
import Motorsport.Circuit.Relief as Relief exposing (Relief)
import Motorsport.Circuit.Shape as Shape exposing (Shape)
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


pace : Pace
pace =
    Pace.fromShape Nothing stadium


{-| Seconds per metre over the ten metres from a distance.
-}
slowness : Float -> Float
slowness =
    slownessOf pace


slownessOf : Pace -> Float -> Float
slownessOf of_ metres =
    (Pace.secondsAt of_ (metres + 10) - Pace.secondsAt of_ metres) / 10


tests : Test
tests =
    describe "Motorsport.Circuit.Pace"
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
                slownessOf (Pace.fromShape (Just hill) stadium) 800
                    |> Expect.greaterThan (slowness 800)
        , test "a descent is taken quicker than the same straight on the level" <|
            \_ ->
                slownessOf (Pace.fromShape (Just hill) stadium) 1500
                    |> Expect.lessThan (slowness 1500)
        , test "metresAt undoes secondsAt" <|
            \_ ->
                [ 0, 123, 1000, 1080, 2300 ]
                    |> List.map (Pace.secondsAt pace >> Pace.metresAt pace)
                    |> List.map2 (\expected actual -> abs (expected - actual)) [ 0, 123, 1000, 1080, 2300 ]
                    |> List.maximum
                    |> Maybe.withDefault 0
                    |> Expect.atMost 0.001
        , test "a distance a lap on is reached a lap's time later" <|
            \_ ->
                Pace.secondsAt pace (Shape.length stadium + 300)
                    |> Expect.within (Expect.Absolute 0.001)
                        (Pace.secondsAt pace (Shape.length stadium) + Pace.secondsAt pace 300)
        , test "an even pace takes a second over each metre" <|
            \_ ->
                Pace.secondsAt Pace.even 1234
                    |> Expect.equal 1234
        ]
