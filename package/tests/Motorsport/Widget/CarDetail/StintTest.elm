module Motorsport.Widget.CarDetail.StintTest exposing (suite)

import Expect
import Motorsport.Driver as Driver
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Widget.CarDetail.Stint as Stint
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Widget.CarDetail.Stint"
        [ describe "summarize"
            [ test "a car that has not stopped is on its first run" <|
                \_ ->
                    [ lap 1 95000, lap 2 96000, lap 3 97000 ]
                        |> Stint.summarize
                        |> .current
                        |> Maybe.map (\stint -> ( stint.number, stint.firstLap, stint.lastLap ))
                        |> Expect.equal (Just ( 1, 1, 3 ))
            , test "the lap a stop ended on closes the run it fell on" <|
                \_ ->
                    [ lap 1 95000, pitLap 2 96000 63000, lap 3 97000 ]
                        |> Stint.summarize
                        |> .stints
                        |> List.map (\stint -> ( stint.firstLap, stint.lastLap ))
                        |> Expect.equal [ ( 1, 2 ), ( 3, 3 ) ]
            , test "a car sitting in the pits is on no run" <|
                \_ ->
                    [ lap 1 95000, pitLap 2 96000 63000 ]
                        |> Stint.summarize
                        |> .current
                        |> Expect.equal Nothing
            , test "the stops are the laps that carry one" <|
                \_ ->
                    [ lap 1 95000, pitLap 2 96000 63000, lap 3 97000, pitLap 4 98000 71000 ]
                        |> Stint.summarize
                        |> .pitStops
                        |> Expect.equal
                            [ { lapNumber = 2, duration = 63000 }
                            , { lapNumber = 4, duration = 71000 }
                            ]
            , test "the lap a stop fell on is left out of the run's times" <|
                \_ ->
                    [ lap 1 95000, lap 2 97000, pitLap 3 150000 63000 ]
                        |> Stint.summarize
                        |> .stints
                        |> List.map (\stint -> ( stint.averageLapTime, stint.bestLapTime ))
                        |> Expect.equal [ ( Just 96000, Just 95000 ) ]
            , test "the run in progress is left out of the median" <|
                \_ ->
                    -- Runs of 2, 4 and a 1 still going: the median is of the two
                    -- that ended, not dragged down by the one that has not.
                    [ lap 1 95000
                    , pitLap 2 96000 63000
                    , lap 3 95000
                    , lap 4 95000
                    , lap 5 95000
                    , pitLap 6 96000 63000
                    , lap 7 95000
                    ]
                        |> Stint.summarize
                        |> .medianStintLength
                        |> Expect.equal (Just 2)
            , test "a car that has turned no lap has run nothing" <|
                \_ ->
                    []
                        |> Stint.summarize
                        |> Expect.all
                            [ .stints >> Expect.equal []
                            , .current >> Expect.equal Nothing
                            , .pitStops >> Expect.equal []
                            , .medianStintLength >> Expect.equal Nothing
                            ]
            , test "laps read in any order are cut in race order" <|
                \_ ->
                    [ lap 3 97000, lap 1 95000, pitLap 2 96000 63000 ]
                        |> Stint.summarize
                        |> .stints
                        |> List.map .lastLap
                        |> Expect.equal [ 2, 3 ]
            ]
        ]


lap : Int -> Int -> Lap
lap lapNumber time =
    { empty | lap = lapNumber, time = Just time }


pitLap : Int -> Int -> Int -> Lap
pitLap lapNumber time pitTime =
    { empty | lap = lapNumber, time = Just time, pitTime = Just pitTime }


empty : Lap
empty =
    let
        base =
            Lap.empty
    in
    { base | carNumber = "7", driver = Driver.fromName "Kamui KOBAYASHI" }
