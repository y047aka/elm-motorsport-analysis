module Motorsport.Race.StintTest exposing (suite)

import Expect
import Motorsport.Driver as Driver
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (unknown)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Stint as Stint
import Motorsport.Wec.Class as Class
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
        , describe "stopsAt"
            [ test "a car that has not stopped has stopped never" <|
                \_ ->
                    [ carWith "1" [ lapAt 1 100000, lapAt 2 200000 ] ]
                        |> Stint.indexOf
                        |> Stint.stopsAt { elapsed = instant 999999 } "1"
                        |> Expect.equal 0
            , test "the count goes up as the lap the stop ended on is completed" <|
                \_ ->
                    let
                        index =
                            Stint.indexOf
                                [ carWith "1" [ lapAt 1 100000, pitLapAt 2 260000 63000 ] ]
                    in
                    [ 259999, 260000, 260001 ]
                        |> List.map (\at -> Stint.stopsAt { elapsed = instant at } "1" index)
                        |> Expect.equal [ 0, 1, 1 ]
            , test "each car is counted on its own" <|
                \_ ->
                    let
                        index =
                            Stint.indexOf
                                [ carWith "1" [ pitLapAt 1 100000 63000, pitLapAt 2 300000 61000 ]
                                , carWith "2" [ pitLapAt 1 200000 65000 ]
                                ]
                    in
                    [ "1", "2" ]
                        |> List.map (\car -> Stint.stopsAt { elapsed = instant 250000 } car index)
                        |> Expect.equal [ 1, 1 ]
            , test "a car the race has never heard of has made none" <|
                \_ ->
                    [ carWith "1" [ pitLapAt 1 100000 63000 ] ]
                        |> Stint.indexOf
                        |> Stint.stopsAt { elapsed = instant 999999 } "99"
                        |> Expect.equal 0
            , test "an index over no race at all counts nothing" <|
                \_ ->
                    Stint.emptyIndex
                        |> Stint.stopsAt { elapsed = instant 999999 } "1"
                        |> Expect.equal 0
            , test "stops read in any order are counted in race order" <|
                \_ ->
                    let
                        index =
                            Stint.indexOf
                                [ carWith "1" [ pitLapAt 3 300000 61000, pitLapAt 1 100000 63000 ] ]
                    in
                    [ 99999, 100000, 299999, 300000 ]
                        |> List.map (\at -> Stint.stopsAt { elapsed = instant at } "1" index)
                        |> Expect.equal [ 0, 1, 1, 2 ]
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


{-| The laps an index is read off carry the moment they were completed, which
the cutting above has no use for.
-}
lapAt : Int -> Int -> Lap
lapAt lapNumber elapsed =
    { empty | lap = lapNumber, elapsed = instant elapsed }


pitLapAt : Int -> Int -> Int -> Lap
pitLapAt lapNumber elapsed pitTime =
    { empty | lap = lapNumber, elapsed = instant elapsed, pitTime = Just pitTime }


instant : Int -> Instant
instant =
    Instant.fromDuration


carWith : CarNumber -> List Lap -> Car
carWith carNumber laps =
    { metadata =
        { carNumber = carNumber
        , drivers = [ Driver.fromName "Kamui KOBAYASHI" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = unknown
        , imageUrl = Nothing
        }
    , startPosition = 1
    , laps = laps
    }
