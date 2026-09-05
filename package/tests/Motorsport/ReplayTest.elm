module Motorsport.ReplayTest exposing (suite)

import Expect
import Motorsport.BestTimes as BestTimes
import Motorsport.Internal.ChangePoints as ChangePoints
import Motorsport.Wec.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Driver as Driver
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (unknown)
import Motorsport.Race.Car as Car exposing (Car, CarNumber)
import Motorsport.Race as Race
import Motorsport.Replay as Replay
import Motorsport.Status as Status exposing (Status)
import Motorsport.Race.Snapshot as Snapshot
import Test exposing (Test, describe, test)
import Time exposing (millisToPosix)


suite : Test
suite =
    describe "Replay"
        [ describe "status is a function of the elapsed time, not of the path taken to it"
            [ test "landing inside a pit window puts the car in the pits, and past it back on track" <|
                \_ ->
                    [ 180000, 250000 ]
                        |> List.map (\elapsed -> statusOf "1" (skipTo elapsed initialModel))
                        |> Expect.equal [ Just Status.InPit, Just Status.Racing ]
            , test "jumping clear past a retirement retires the car" <|
                \_ ->
                    initialModel
                        |> skipTo 1000000
                        |> statusOf "1"
                        |> Expect.equal (Just Status.Retired)
            , test "rewinding back into a pit window puts the car back in the pits" <|
                \_ ->
                    initialModel
                        |> skipTo 200000
                        |> skipBy -20000
                        |> statusOf "1"
                        |> Expect.equal (Just Status.InPit)
            , test "rewinding from a retirement brings the car back to racing" <|
                \_ ->
                    initialModel
                        |> skipTo 1000000
                        |> skipTo 250000
                        |> statusOf "1"
                        |> Expect.equal (Just Status.Racing)
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
                        |> Expect.equal (Just Status.Checkered)
            ]
        , describe "while the race is running"
            -- Every case above moves a stopped clock. A running one reports its
            -- elapsed from an anchor, and moving it has to move the anchor too.
            [ test "skipping lands on the moment asked for, not that much further on" <|
                \_ ->
                    playingAt 100000
                        |> skipBy 10000
                        |> elapsedOf
                        |> Expect.equal 110000
            , test "and the status follows the head" <|
                \_ ->
                    -- 100.000 + 80.000 is inside car "1"'s pit window.
                    playingAt 100000
                        |> skipBy 80000
                        |> statusOf "1"
                        |> Expect.equal (Just Status.InPit)
            ]
        , describe "playback runs to the finish, not to the flag"
            -- The flag falls on a lap already under way; the closing laps sit
            -- between the two.
            [ test "skipping carries on past the time limit" <|
                \_ ->
                    initialModel
                        |> skipTo 7200000
                        |> skipBy 100000
                        |> elapsedOf
                        |> Expect.equal 7300000
            , test "and stops once the last car has crossed the line" <|
                \_ ->
                    initialModel
                        |> skipTo 7300000
                        |> skipBy 1000
                        |> elapsedOf
                        |> Expect.equal 7300000
            , test "a running clock ticks through the closing laps too" <|
                \_ ->
                    playingAt 7250000
                        |> elapsedOf
                        |> Expect.equal 7250000
            , test "and runs out at the last crossing" <|
                \_ ->
                    playingAt 7400000
                        |> elapsedOf
                        |> Expect.equal 7300000
            , test "skipping further than there is race left lands on the end of it" <|
                \_ ->
                    initialModel
                        |> skipBy 99999999
                        |> elapsedOf
                        |> Expect.equal 7300000
            ]
        , describe "SetCount"
            [ test "moving the lap counter forward carries the status with it" <|
                \_ ->
                    -- The end of lap 1 is the instant before car "1" completes
                    -- lap 2, which it spends in the pits.
                    initialModel
                        |> Replay.update (Replay.SetCount 1)
                        |> statusOf "1"
                        |> Expect.equal (Just Status.InPit)
            ]
        ]



-- FIXTURE
-- A two-hour race. Car "1" retires after three laps, pitting on lap 2; car "2"
-- runs past the flag -- which is what makes car "1"'s final lap a retirement
-- rather than a chequered flag, and puts the finish 100.000 after the limit.


initialModel : Replay.Model
initialModel =
    Replay.fromCars
        { timeLimit = Instant.fromDuration 7200000
        , finishedAt = Instant.fromDuration 7300000
        , index = index
        }
        [ retiringCar, survivingCar ]


{-| The indices the round is read with, as `Round.Index` counts them out of the
rows: both cars complete lap 1 at 100.000, and car "1" leads the two after that.
-}
index : Race.Index
index =
    { lapCompletions =
        ChangePoints.fromList
            [ ( Instant.fromDuration 100000, 1 )
            , ( Instant.fromDuration 200000, 2 )
            , ( Instant.fromDuration 300000, 3 )
            ]
    , bestTimeChanges = BestTimes.empty
    }


retiringCar : Car
retiringCar =
    carWith "1"
        [ lapAt "1" 1 100000
        , lapAt "1" 2 200000 |> withPitTime (Just 30000)
        , lapAt "1" 3 300000
        ]


survivingCar : Car
survivingCar =
    carWith "2"
        [ lapAt "2" 1 100000
        , lapAt "2" 2 7300000
        ]



-- HELPERS


{-| The fixture with playback started and ticked to `elapsed`.
-}
playingAt : Int -> Replay.Model
playingAt elapsed =
    initialModel
        |> Replay.update (Replay.Start (millisToPosix 0))
        |> Replay.update (Replay.Tick (millisToPosix elapsed))


{-| As plain milliseconds, which is what the expectations below are written in.
-}
elapsedOf : Replay.Model -> Int
elapsedOf m =
    Instant.toDuration (Clock.getElapsed m.playback)


skipTo : Int -> Replay.Model -> Replay.Model
skipTo elapsed m =
    skipBy (elapsed - elapsedOf m) m


skipBy : Int -> Replay.Model -> Replay.Model
skipBy duration =
    Replay.update (Replay.SkipTime duration)


{-| The status as a snapshot of the race shows it, which is the whole point: the
model holds no status of its own, it is read back out of the race at the clock.
-}
statusOf : CarNumber -> Replay.Model -> Maybe Status
statusOf carNumber { race, playback } =
    Snapshot.at { elapsed = Clock.getElapsed playback } race
        |> Snapshot.toList
        |> List.filter (\car -> car.metadata.carNumber == carNumber)
        |> List.head
        |> Maybe.map .status


carWith : CarNumber -> List Lap -> Car
carWith carNumber laps =
    { metadata =
        { carNumber = carNumber
        , drivers = [ Driver.fromName "Test Driver" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = unknown
        }
    , startPosition = 1
    , laps = laps
    }


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
        , elapsed = Instant.fromDuration elapsed
    }


withPitTime : Maybe Int -> Lap -> Lap
withPitTime pitTime lap =
    { lap | pitTime = pitTime }
