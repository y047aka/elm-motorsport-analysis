module Motorsport.RaceTest exposing (suite)

import Expect
import Motorsport.Class as Class
import Motorsport.Driver as Driver
import Motorsport.Entrant as Entrant exposing (Entrant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (Manufacturer(..))
import Motorsport.Race as Race exposing (Race)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Race"
        [ describe "lapCountAt"
            [ test "reads zero until the first car has completed a lap" <|
                \_ ->
                    [ -1, 0, 89999 ]
                        |> List.map (\elapsed -> Race.lapCountAt elapsed race)
                        |> Expect.equal [ 0, 0, 0 ]
            , test "goes up the moment the first car of the field crosses the line" <|
                \_ ->
                    -- Car 2 leads lap 1 (90.000 against car 1's 100.000), so the
                    -- counter reads 1 from 90.000, not 100.000.
                    Expect.equal
                        ( 0, 1 )
                        ( Race.lapCountAt 89999 race
                        , Race.lapCountAt 90000 race
                        )
            , test "holds the final count once the laps run out" <|
                \_ ->
                    Race.lapCountAt 99999999 race
                        |> Expect.equal 3
            , test "a race with no entrants is always on lap zero" <|
                \_ ->
                    Race.lapCountAt 500000 Race.empty
                        |> Expect.equal 0
            ]
        , describe "elapsedAtLapCount"
            [ test "lands on the last instant the counter still reads that lap" <|
                \_ ->
                    [ 0, 1, 2 ]
                        |> List.map (\lapCount -> Race.elapsedAtLapCount lapCount race)
                        |> Expect.equal [ 89999, 199999, 299999 ]
            , test "round-trips through lapCountAt" <|
                \_ ->
                    [ 0, 1, 2, 3 ]
                        |> List.map (\lapCount -> Race.lapCountAt (Race.elapsedAtLapCount lapCount race) race)
                        |> Expect.equal [ 0, 1, 2, 3 ]
            , test "the final lap has no next lap to stop before, so it lands on its completion" <|
                \_ ->
                    -- Car 1 completes lap 3 at 300.000, and nobody goes further.
                    Race.elapsedAtLapCount 3 race
                        |> Expect.equal 300000
            ]
        , describe "lapTotal"
            [ test "counts the laps of whichever car went furthest" <|
                \_ ->
                    race.lapTotal |> Expect.equal 3
            ]
        ]



-- FIXTURE
-- Car 2 leads the first lap and then falls a long way back; car 1 goes on to
-- three laps. The lap counter should follow whoever is in front at the time.


race : Race
race =
    Race.fromEntrants
        [ entrantWith "1"
            [ lapAt "1" 1 100000
            , lapAt "1" 2 200000
            , lapAt "1" 3 300000
            ]
        , entrantWith "2"
            [ lapAt "2" 1 90000
            , lapAt "2" 2 7300000
            ]
        ]


entrantWith : Entrant.CarNumber -> List Lap -> Entrant
entrantWith carNumber laps =
    { metadata =
        { carNumber = carNumber
        , drivers = [ Driver.fromName "Test Driver" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = Other
        }
    , startPosition = 1
    , laps = laps
    }


lapAt : Entrant.CarNumber -> Int -> Int -> Lap
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
        , elapsed = elapsed
    }
