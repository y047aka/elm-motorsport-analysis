module Motorsport.Analysis.EntrantTest exposing (suite)

import Expect
import Internal.ChangePoints as ChangePoints
import Motorsport.Analysis.Entrant as Entrant
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race as Race
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.Entrant"
        [ describe "who the teammates are"
            [ test "the cars the team entered in the car's own class" <|
                \_ ->
                    entrantOf "1"
                        |> Expect.equal (Just [ "3", "1", "2" ])
            , test "a team's cars in another class are another entrant" <|
                \_ ->
                    entrantOf "7"
                        |> Expect.equal (Just [ "7", "8" ])
            , test "one car entered is an entrant of one" <|
                \_ ->
                    entrantOf "5"
                        |> Expect.equal (Just [ "5" ])
            , test "a car the running order does not hold is its own only company" <|
                \_ ->
                    entrantOf "99"
                        |> Expect.equal (Just [ "99" ])
            ]
        , describe "the order they come out in"
            [ test "the running order given, not the order the team entered them" <|
                \_ ->
                    -- The fixture lists 3 before 1 before 2, and the numbers
                    -- would sort the other way.
                    entrantOf "2"
                        |> Expect.equal (Just [ "3", "1", "2" ])
            , test "the car asked about is among them rather than at the front" <|
                \_ ->
                    entrantOf "2"
                        |> Maybe.map (List.member "2")
                        |> Expect.equal (Just True)
            ]
        ]



-- FIXTURE
--
-- Endurance enters three cars in HYPERCAR and two more in LMGT3, which are not
-- one another's teammates: a team in a class is what an entrant is. Solo enters
-- the one car. Car 99 is Endurance's too and is left out of the running order,
-- which is what a car the field does not hold reads as.


entrantOf : String -> Maybe (List String)
entrantOf carNumber =
    carAt carNumber
        |> Maybe.map (Entrant.cars field >> carNumbers)


carNumbers : List CarAt -> List String
carNumbers =
    List.map (.metadata >> .carNumber)


{-| The overall running order, as the views hand it over. `cars` reads the list
as the order rather than sorting it, so this is the order under test.
-}
field : List CarAt
field =
    [ "3", "7", "1", "5", "8", "2" ] |> List.filterMap carAt


carAt : String -> Maybe CarAt
carAt carNumber =
    Snapshot.get carNumber grid


grid : Snapshot
grid =
    Race.fromCars { timeLimit = Instant.raceStart, index = noIndex }
        [ carOf "1" "HYPERCAR" "Endurance"
        , carOf "2" "HYPERCAR" "Endurance"
        , carOf "3" "HYPERCAR" "Endurance"
        , carOf "99" "HYPERCAR" "Endurance"
        , carOf "5" "HYPERCAR" "Solo"
        , carOf "7" "LMGT3" "Endurance"
        , carOf "8" "LMGT3" "Endurance"
        ]
        |> Snapshot.at { elapsed = Instant.fromDuration 30000 }


{-| A car with two laps behind it, which is enough to be in the field. What the
laps say is not read here.
-}
carOf : String -> String -> String -> Car
carOf carNumber class team =
    { metadata = metadataOf carNumber (classOf class) team
    , startPosition = 1
    , laps = [ lapOf carNumber 1 10000, lapOf carNumber 2 20000 ]
    }


lapOf : String -> Int -> Duration -> Lap
lapOf carNumber lapNumber elapsed =
    { emptyLap
        | carNumber = carNumber
        , driver = Driver.fromName ("Driver " ++ carNumber)
        , lap = lapNumber
        , time = Just 10000
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


metadataOf : String -> Class -> String -> Car.Metadata
metadataOf carNumber class team =
    { carNumber = carNumber
    , drivers = [ Driver.fromName ("Driver " ++ carNumber) ]
    , class = class
    , group = "H"
    , team = team
    , manufacturer = Manufacturer.unknown
    , imageUrl = Nothing
    }
