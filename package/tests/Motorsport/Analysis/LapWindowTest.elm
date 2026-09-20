module Motorsport.Analysis.LapWindowTest exposing (suite)

import Expect
import Motorsport.Analysis.LapWindow as LapWindow
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Internal.ChangePoints as ChangePoints
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race as Race
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.LapWindow"
        [ test "the whole race is every lap the class has reached" <|
            \_ ->
                LapWindow.range LapWindow.WholeRace (classOf "HYPERCAR") (fieldAt 25000)
                    |> Expect.equal { first = 1, last = 4 }
        , test "and it is that class's laps, not the race's" <|
            \_ ->
                -- The GT3 car is six laps in where the Hypercars are four.
                LapWindow.range LapWindow.WholeRace (classOf "LMGT3") (fieldAt 25000)
                    |> Expect.equal { first = 1, last = 6 }
        , test "a stretch starts where the running car opened it, not where a stopped one did" <|
            \_ ->
                -- 13.000 back from 25.000 is 12.000, and the running car was on
                -- lap 3 by then. Car 3's last lap is at 6.000, so it has nothing
                -- inside the stretch at all: answering for it would open the
                -- window back out to the whole race.
                LapWindow.range (LapWindow.Recent 13000) (classOf "HYPERCAR") (fieldAt 25000)
                    |> Expect.equal { first = 3, last = 4 }
        , test "a class that has not been running that long yet starts at lap 1" <|
            \_ ->
                LapWindow.range (LapWindow.Recent 60000) (classOf "HYPERCAR") (fieldAt 25000)
                    |> Expect.equal { first = 1, last = 4 }
        ]



-- FIXTURE
--
-- Three cars in two classes: one Hypercar four laps in, its classmate stopped
-- after two, and a GT3 car six laps in to show that the window is read off the
-- one class.


fieldAt : Duration -> Snapshot
fieldAt elapsed =
    Race.fromCars { timeLimit = Instant.raceStart, index = noIndex } [ running, stopped, otherClass ]
        |> Snapshot.at { elapsed = Instant.fromDuration elapsed }


running : Car
running =
    carOf "1" "HYPERCAR" [ 5000, 10000, 15000, 20000 ]


{-| Out of the race at 6.000, and so with nothing inside any recent stretch.
-}
stopped : Car
stopped =
    carOf "3" "HYPERCAR" [ 3000, 6000 ]


otherClass : Car
otherClass =
    carOf "2" "LMGT3" [ 2000, 4000, 6000, 8000, 10000, 12000 ]


{-| A car whose laps end at the given moments, numbered from one.
-}
carOf : String -> String -> List Duration -> Car
carOf carNumber class completions =
    { metadata = metadataOf carNumber (classOf class)
    , startPosition = 1
    , laps =
        completions
            |> List.indexedMap (\i elapsed -> lapOf carNumber (i + 1) elapsed)
    }


lapOf : String -> Int -> Duration -> Lap
lapOf carNumber lapNumber elapsed =
    { emptyLap
        | carNumber = carNumber
        , driver = Driver.fromName ("Driver " ++ carNumber)
        , lap = lapNumber
        , position = Just 1
        , time = Just 5000
        , elapsed = Instant.fromDuration elapsed
    }


emptyLap : Lap
emptyLap =
    Lap.empty


{-| The records a round arrives with, which nothing here reads.
-}
noIndex : Race.Index
noIndex =
    { lapCompletions = ChangePoints.empty
    , bestTimeChanges = BestTimes.empty
    }


classOf : String -> Class
classOf =
    Class.fromString Era.Gt3AsThirdClass


metadataOf : String -> Class -> Car.Metadata
metadataOf carNumber class =
    { carNumber = carNumber
    , drivers = [ Driver.fromName ("Driver " ++ carNumber) ]
    , class = class
    , group = "H"
    , team = "Team " ++ carNumber
    , manufacturer = Manufacturer.unknown
    , imageUrl = Nothing
    }
