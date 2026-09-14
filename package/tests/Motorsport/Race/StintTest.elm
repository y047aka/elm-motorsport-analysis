module Motorsport.Race.StintTest exposing (suite)

import Expect
import Motorsport.Driver as Driver
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Stint as Stint
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Race.Stint"
        [ describe "fromLaps"
            [ test "a car that has not stopped has run one" <|
                \_ ->
                    [ lap 1 95000, lap 2 96000, lap 3 97000 ]
                        |> Stint.fromLaps
                        |> List.map (\stint -> ( stint.number, stint.firstLap, stint.lastLap ))
                        |> Expect.equal [ ( 1, 1, 3 ) ]
            , test "the lap a stop ended on closes the run it fell on" <|
                \_ ->
                    [ lap 1 95000, pitLap 2 96000 63000, lap 3 97000 ]
                        |> Stint.fromLaps
                        |> List.map (\stint -> ( stint.firstLap, stint.lastLap ))
                        |> Expect.equal [ ( 1, 2 ), ( 3, 3 ) ]
            , test "a run that ended carries the stop that ended it" <|
                \_ ->
                    [ lap 1 95000, pitLap 2 96000 63000, lap 3 97000, pitLap 4 98000 71000 ]
                        |> Stint.fromLaps
                        |> List.map .pit
                        |> Expect.equal
                            [ Just { lapNumber = 2, duration = 63000 }
                            , Just { lapNumber = 4, duration = 71000 }
                            ]
            , test "the lap a stop fell on is left out of the run's times" <|
                \_ ->
                    [ lap 1 95000, lap 2 97000, pitLap 3 150000 63000 ]
                        |> Stint.fromLaps
                        |> List.map (\stint -> ( stint.averageLapTime, stint.bestLapTime ))
                        |> Expect.equal [ ( Just 96000, Just 95000 ) ]
            , test "laps read in any order are cut in race order" <|
                \_ ->
                    [ lap 3 97000, lap 1 95000, pitLap 2 96000 63000 ]
                        |> Stint.fromLaps
                        |> List.map .lastLap
                        |> Expect.equal [ 2, 3 ]
            , test "a car that has turned no lap has run nothing" <|
                \_ ->
                    []
                        |> Stint.fromLaps
                        |> Expect.equal []
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
