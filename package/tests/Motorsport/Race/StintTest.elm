module Motorsport.Race.StintTest exposing (suite)

import Expect
import Motorsport.Driver as Driver
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (unknown)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Stint as Stint exposing (End(..))
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
            , test "the lap the car came in on closes the run, and the lap it came out on opens the next" <|
                \_ ->
                    [ lap 1 95000, inLap 2 101000, outLap 3 165000 63000 ]
                        |> Stint.fromLaps
                        |> List.map (\stint -> ( stint.firstLap, stint.lastLap ))
                        |> Expect.equal [ ( 1, 2 ), ( 3, 3 ) ]
            , test "a run that ended carries the stop that ended it, read off the lap after it" <|
                \_ ->
                    [ lap 1 95000, inLap 2 101000, outLap 3 165000 63000, inLap 4 101000, outLap 5 173000 71000 ]
                        |> Stint.fromLaps
                        |> List.map .end
                        |> Expect.equal
                            [ Ended { lapNumber = 3, duration = 63000 }
                            , Ended { lapNumber = 5, duration = 71000 }
                            , Running
                            ]
            , test "a car sitting in the pits has ended a run with no stop to show for it yet" <|
                \_ ->
                    [ lap 1 95000, inLap 2 101000 ]
                        |> Stint.fromLaps
                        |> List.map .end
                        |> Expect.equal [ InPit ]
            , test "a car that came out and went straight back in has run one lap" <|
                \_ ->
                    [ lap 1 95000, inLap 2 101000, outAndIn 3 166000 46857, outLap 4 173000 69107 ]
                        |> Stint.fromLaps
                        |> List.map (\stint -> ( stint.lapCount, stint.end ))
                        |> Expect.equal
                            [ ( 2, Ended { lapNumber = 3, duration = 46857 } )
                            , ( 1, Ended { lapNumber = 4, duration = 69107 } )
                            , ( 1, Running )
                            ]
            , test "the laps that touched the pit lane are left out of the run's times" <|
                \_ ->
                    [ outLap 1 160000 63000, lap 2 95000, lap 3 97000, inLap 4 150000 ]
                        |> Stint.fromLaps
                        |> List.map (\stint -> ( stint.averageLapTime, stint.bestLapTime ))
                        |> Expect.equal [ ( Just 96000, Just 95000 ) ]
            , test "laps read in any order are cut in race order" <|
                \_ ->
                    [ outLap 3 165000 63000, lap 1 95000, inLap 2 101000 ]
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
            , test "the count goes up as the car drives away, not as the lap it drove away on ends" <|
                \_ ->
                    let
                        index =
                            Stint.indexOf
                                [ carWith "1" [ lapAt 1 100000, outLapAt 2 260000 160000 63000 ] ]
                    in
                    -- The lap began at 100000 and the stop took 63000, so the
                    -- car was away at 163000 and the lap ran on to 260000.
                    [ 162999, 163000, 259999, 260001 ]
                        |> List.map (\at -> Stint.stopsAt { elapsed = instant at } "1" index)
                        |> Expect.equal [ 0, 1, 1, 1 ]
            , test "each car is counted on its own" <|
                \_ ->
                    let
                        index =
                            Stint.indexOf
                                [ carWith "1" [ outLapAt 1 100000 100000 63000, outLapAt 2 300000 100000 61000 ]
                                , carWith "2" [ outLapAt 1 200000 100000 65000 ]
                                ]
                    in
                    [ "1", "2" ]
                        |> List.map (\car -> Stint.stopsAt { elapsed = instant 250000 } car index)
                        |> Expect.equal [ 1, 1 ]
            , test "a car the race has never heard of has made none" <|
                \_ ->
                    [ carWith "1" [ outLapAt 1 100000 100000 63000 ] ]
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
                                [ carWith "1" [ outLapAt 3 300000 100000 61000, outLapAt 1 100000 100000 63000 ] ]
                    in
                    [ 62999, 63000, 260999, 261000 ]
                        |> List.map (\at -> Stint.stopsAt { elapsed = instant at } "1" index)
                        |> Expect.equal [ 0, 1, 1, 2 ]
            ]
        ]


lap : Int -> Int -> Lap
lap lapNumber time =
    { empty | lap = lapNumber, time = Just time }


{-| The lap the car came in on, which carries no stop of its own.
-}
inLap : Int -> Int -> Lap
inLap lapNumber time =
    { empty | lap = lapNumber, time = Just time, pit = Lap.InLap }


{-| The lap the car came back out on, which is where the feed times the stop.
-}
outLap : Int -> Int -> Int -> Lap
outLap lapNumber time stop =
    { empty | lap = lapNumber, time = Just time, pit = Lap.OutLap stop }


outAndIn : Int -> Int -> Int -> Lap
outAndIn lapNumber time stop =
    { empty | lap = lapNumber, time = Just time, pit = Lap.OutAndIn stop }


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


{-| An out lap carries its own time as well, which is what puts the stop it
began with at the head of it.
-}
outLapAt : Int -> Int -> Int -> Int -> Lap
outLapAt lapNumber elapsed time stop =
    { empty | lap = lapNumber, elapsed = instant elapsed, time = Just time, pit = Lap.OutLap stop }


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
