module Motorsport.ViewModelTest exposing (suite)

import Expect
import Motorsport.BestTimes as BestTimes
import Motorsport.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (Manufacturer(..))
import Motorsport.Race.Car exposing (Car)
import Motorsport.Replay as Replay
import Motorsport.ViewModel as ViewModel exposing (Scope(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.ViewModel"
        [ describe "the scope decides how wide the comparison baseline is drawn"
            -- The clock sits at 6.000, by which point only the slower of the two
            -- laps has been run. The quicker one ends at 11.000, ahead of it.
            [ test "UpToElapsed draws it from the laps run so far" <|
                \_ ->
                    fastestLapTimeAt 6000 UpToElapsed
                        |> Expect.equal (Just 6000)
            , test "WholeRace draws it from every lap, the ones ahead of the clock included" <|
                \_ ->
                    fastestLapTimeAt 6000 WholeRace
                        |> Expect.equal (Just 5000)
            ]
        ]



-- FIXTURE
-- One car improving on itself: a 6.000 lap, then a 5.000 one.


fastestLapTimeAt : Duration -> Scope -> Maybe Duration
fastestLapTimeAt elapsed scope =
    replayAt elapsed
        |> ViewModel.compute scope
        |> .bestTimes
        |> .fastestLapTime
        |> BestTimes.timeOf


{-| The head put straight where the test wants it, rather than skipped there:
where playback is allowed to move is [`Replay`](Motorsport-Replay)'s business,
and none of it bears on which laps the scope counts.
-}
replayAt : Duration -> Replay.Model
replayAt elapsed =
    let
        m =
            Replay.fromCars [ improvingCar ]
    in
    { m | playback = Clock.setElapsed (Instant.fromDuration elapsed) m.playback }


improvingCar : Car
improvingCar =
    { metadata =
        { carNumber = "1"
        , drivers = [ Driver.fromName "Test Driver" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = Other
        }
    , startPosition = 1
    , laps =
        [ lapOf 1 6000 6000
        , lapOf 2 5000 11000
        ]
    }


lapOf : Int -> Duration -> Duration -> Lap
lapOf lapNumber time elapsed =
    let
        base =
            Lap.empty
    in
    { base
        | carNumber = "1"
        , driver = Driver.fromName "Test Driver"
        , lap = lapNumber
        , position = Just 1
        , time = Just time
        , elapsed = Instant.fromDuration elapsed
    }
