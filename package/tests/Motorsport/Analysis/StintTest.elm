module Motorsport.Analysis.StintTest exposing (suite)

import Expect
import Motorsport.Analysis.Stint as Stint
import Motorsport.Driver as Driver
import Motorsport.Lap as Lap exposing (Lap)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.Stint"
        [ describe "summarize"
            [ test "a car that has not stopped is on its first run" <|
                \_ ->
                    [ lap 1 95000, lap 2 96000, lap 3 97000 ]
                        |> Stint.summarize
                        |> Stint.current
                        |> Maybe.map (\stint -> ( stint.number, stint.firstLap, stint.lastLap ))
                        |> Expect.equal (Just ( 1, 1, 3 ))
            , test "a car sitting in the pits is on no run" <|
                \_ ->
                    [ lap 1 95000, inLap 2 101000 ]
                        |> Stint.summarize
                        |> Stint.current
                        |> Expect.equal Nothing
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
                        |> Stint.medianStintLength
                        |> Expect.equal (Just 2)
            , test "a car that has turned no lap has run nothing" <|
                \_ ->
                    []
                        |> Stint.summarize
                        |> Expect.all
                            [ Stint.all >> Expect.equal []
                            , Stint.current >> Expect.equal Nothing
                            , Stint.medianStintLength >> Expect.equal Nothing
                            ]
            ]
        , describe "lapsDrivenBy"
            [ test "the laps of every run the driver took out" <|
                \_ ->
                    -- A run of three and a run of two, the second taken out by
                    -- the other driver: a run is driven by whoever its first
                    -- lap names.
                    [ lap 1 95000
                    , lap 2 95000
                    , inLap 3 101000
                    , outLap 4 165000 63000 |> drivenBy "Mike CONWAY"
                    , lap 5 95000 |> drivenBy "Mike CONWAY"
                    ]
                        |> Stint.summarize
                        |> Stint.lapsDrivenBy (Driver.fromName "Mike CONWAY")
                        |> Expect.equal 2
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


drivenBy : String -> Lap -> Lap
drivenBy name aLap =
    { aLap | driver = Driver.fromName name }


empty : Lap
empty =
    let
        base =
            Lap.empty
    in
    { base | carNumber = "7", driver = Driver.fromName "Kamui KOBAYASHI" }
