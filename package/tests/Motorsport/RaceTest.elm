module Motorsport.RaceTest exposing (suite)

import Expect
import Motorsport.Circuit as Circuit
import Motorsport.Wec.Class as Class
import Motorsport.Driver as Driver
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Wec.Manufacturer exposing (Manufacturer(..))
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car exposing (Car, CarNumber)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Race"
        [ describe "lapCountAt"
            [ test "reads zero before the race has begun" <|
                \_ ->
                    [ -1, 0 ]
                        |> List.map (\elapsed -> Race.lapCountAt { elapsed = instant elapsed } race)
                        |> Expect.equal [ 0, 0 ]
            , test "goes up the moment the first car of the field crosses the line" <|
                \_ ->
                    -- Car 2 leads lap 1 (90.000 against car 1's 100.000), so the
                    -- counter reads 1 from 90.000, not 100.000.
                    Expect.equal
                        ( 0, 1 )
                        ( Race.lapCountAt { elapsed = instant 89999 } race
                        , Race.lapCountAt { elapsed = instant 90000 } race
                        )
            , test "holds the final count once the laps run out" <|
                \_ ->
                    Race.lapCountAt { elapsed = instant 99999999 } race
                        |> Expect.equal 3
            , test "a race with no cars is always on lap zero" <|
                \_ ->
                    Race.lapCountAt { elapsed = instant 500000 } Race.empty
                        |> Expect.equal 0
            ]
        , describe "elapsedAtLapCount"
            [ test "lands on the last instant the counter still reads that lap" <|
                \_ ->
                    [ 0, 1, 2 ]
                        |> List.map (\lapCount -> Race.elapsedAtLapCount lapCount race)
                        |> Expect.equal [ instant 89999, instant 199999, instant 299999 ]
            , test "round-trips through lapCountAt" <|
                \_ ->
                    [ 0, 1, 2, 3 ]
                        |> List.map (\lapCount -> Race.lapCountAt { elapsed = Race.elapsedAtLapCount lapCount race } race)
                        |> Expect.equal [ 0, 1, 2, 3 ]
            , test "the final lap has no next lap to stop before, so it lands on its completion" <|
                \_ ->
                    -- Car 1 completes lap 3 at 300.000, and nobody goes further.
                    Race.elapsedAtLapCount 3 race
                        |> Expect.equal (instant 300000)
            , test "a count the race never reached lands at the start" <|
                \_ ->
                    -- Total on its own: no caller has to have range-checked first.
                    [ Race.elapsedAtLapCount (-1) race
                    , Race.elapsedAtLapCount 0 Race.empty
                    ]
                        |> Expect.equal [ Instant.raceStart, Instant.raceStart ]
            ]
        , describe "lapTotal"
            [ test "is the ceiling lapCountAt can actually reach" <|
                \_ ->
                    -- Both come off lapCompletions, so they cannot disagree.
                    Race.lapCountAt { elapsed = instant 99999999 } race
                        |> Expect.equal race.lapTotal
            ]
        ]



-- FIXTURE
-- Car 2 leads the first lap and then falls a long way back; car 1 goes on to
-- three laps. The lap counter should follow whoever is in front at the time.


race : Race
race =
    Race.fromCars Circuit.clockwise
        [ carWith "1"
            [ lapAt "1" 1 100000
            , lapAt "1" 2 200000
            , lapAt "1" 3 300000
            ]
        , carWith "2"
            [ lapAt "2" 1 90000
            , lapAt "2" 2 7300000
            ]
        ]


carWith : CarNumber -> List Lap -> Car
carWith carNumber laps =
    { metadata =
        { carNumber = carNumber
        , drivers = [ Driver.fromName "Test Driver" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = Other
        }
    , startPosition = Just 1
    , laps = laps
    }


{-| The fixtures are written in plain milliseconds and lifted to
[`Instant`](Motorsport-Instant) here, so the numbers stay readable.
-}
instant : Int -> Instant
instant =
    Instant.fromDuration


lapAt : CarNumber -> Int -> Int -> Lap
lapAt carNumber lapNumber elapsed =
    let
        base =
            Lap.empty
    in
    { base
        | carNumber = carNumber
        , driver = Driver.fromName "Test Driver"
        , lap = lapNumber
        , position = Just 1
        , elapsed = instant elapsed
    }
