module Motorsport.ReplayTest exposing (suite)

import Expect
import Motorsport.Car as Car
import Motorsport.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Driver as Driver
import Motorsport.Entrant as Entrant exposing (Entrant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (Manufacturer(..))
import Motorsport.Replay as Replay
import Motorsport.ViewModel as ViewModel
import Motorsport.ViewModel.BestTimes exposing (Scope(..))
import Motorsport.ViewModel.Standings as Standings
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Replay"
        [ describe "status is a function of the elapsed time, not of the path taken to it"
            [ test "landing inside a pit window puts the car in the pits" <|
                \_ ->
                    initialModel
                        |> skipTo 180000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.InPit)
            , test "landing between the pit exit and the next event leaves the car racing" <|
                \_ ->
                    initialModel
                        |> skipTo 250000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.Racing)
            , test "jumping clear past a retirement retires the car" <|
                \_ ->
                    initialModel
                        |> skipTo 1000000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.Retired)
            , test "rewinding back into a pit window puts the car back in the pits" <|
                \_ ->
                    initialModel
                        |> skipTo 200000
                        |> skipBy -20000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.InPit)
            , test "rewinding from a retirement brings the car back to racing" <|
                \_ ->
                    initialModel
                        |> skipTo 1000000
                        |> skipTo 250000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.Racing)
            , test "one jump and many small steps to the same elapsed agree" <|
                \_ ->
                    let
                        inOneJump =
                            initialModel |> skipTo 260000

                        inManySteps =
                            List.foldl (\_ m -> skipBy 1000 m) initialModel (List.range 1 260)
                    in
                    Expect.equal
                        (statusOf "1" inOneJump)
                        (statusOf "1" inManySteps)
            , test "a car still running past the time limit takes the chequered flag, not a retirement" <|
                \_ ->
                    initialModel
                        |> skipTo 7300000
                        |> statusOf "2"
                        |> Expect.equal (Just Car.Checkered)
            ]
        , describe "SetCount"
            [ test "moving the lap counter forward carries the status with it" <|
                \_ ->
                    -- The end of lap 1 is the instant before car "1" completes
                    -- lap 2, which it spends in the pits.
                    initialModel
                        |> Replay.update (Replay.SetCount 1)
                        |> statusOf "1"
                        |> Expect.equal (Just Car.InPit)
            ]
        ]



-- FIXTURE
-- Car "1" retires after three laps, pitting on lap 2. Car "2" runs past the two
-- hour mark, so the rounded time limit is 2h -- which is what makes car "1"'s
-- final lap a retirement rather than a chequered flag.


initialModel : Replay.Model
initialModel =
    let
        entrants =
            [ retiringCar, survivingCar ]
    in
    Replay.fromEntrants entrants


retiringCar : Entrant
retiringCar =
    entrantWith "1"
        [ lapAt "1" 1 100000
        , lapAt "1" 2 200000 |> withPitTime (Just 30000)
        , lapAt "1" 3 300000
        ]


survivingCar : Entrant
survivingCar =
    entrantWith "2"
        [ lapAt "2" 1 100000
        , lapAt "2" 2 7300000
        ]



-- HELPERS


skipTo : Int -> Replay.Model -> Replay.Model
skipTo elapsed m =
    skipBy (elapsed - Clock.getElapsed m.playback) m


skipBy : Int -> Replay.Model -> Replay.Model
skipBy duration =
    Replay.update (Replay.SkipTime duration)


{-| The status as the standings show it, which is the whole point: the model
holds no status of its own, it is read back out of the race at the clock.
-}
statusOf : Entrant.CarNumber -> Replay.Model -> Maybe Car.Status
statusOf carNumber m =
    ViewModel.compute UpToElapsed m
        |> .standings
        |> Standings.toList
        |> List.filter (\entry -> entry.metadata.carNumber == carNumber)
        |> List.head
        |> Maybe.map .status


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


withPitTime : Maybe Int -> Lap -> Lap
withPitTime pitTime lap =
    { lap | pitTime = pitTime }
