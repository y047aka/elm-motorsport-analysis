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
            , test "a car sitting in the pits is on no run" <|
                \_ ->
                    [ lap 1 95000, inLap 2 101000 ]
                        |> Stint.summarize
                        |> .current
                        |> Expect.equal Nothing
            , test "the stops are the laps the car came back out on" <|
                \_ ->
                    [ lap 1 95000, inLap 2 101000, outLap 3 165000 63000, inLap 4 101000, outLap 5 173000 71000 ]
                        |> Stint.summarize
                        |> .pitStops
                        |> Expect.equal
                            [ { lapNumber = 3, duration = 63000 }
                            , { lapNumber = 5, duration = 71000 }
                            ]
            , test "a stop the car is still making is not one it has made" <|
                \_ ->
                    [ lap 1 95000, inLap 2 101000 ]
                        |> Stint.summarize
                        |> .pitStops
                        |> Expect.equal []
            , test "the run in progress is left out of the median" <|
                \_ ->
                    -- Runs of 2, 4 and a 1 still going: the median is of the two
                    -- that ended, not dragged down by the one that has not.
                    [ lap 1 95000
                    , inLap 2 101000
                    , outLap 3 165000 63000
                    , lap 4 95000
                    , lap 5 95000
                    , inLap 6 101000
                    , outLap 7 165000 63000
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
            ]
        ]


lap : Int -> Int -> Lap
lap lapNumber time =
    { empty | lap = lapNumber, time = Just time }


inLap : Int -> Int -> Lap
inLap lapNumber time =
    { empty | lap = lapNumber, time = Just time, pit = Lap.InLap }


outLap : Int -> Int -> Int -> Lap
outLap lapNumber time stop =
    { empty | lap = lapNumber, time = Just time, pit = Lap.OutLap stop }


empty : Lap
empty =
    let
        base =
            Lap.empty
    in
    { base | carNumber = "7", driver = Driver.fromName "Kamui KOBAYASHI" }
