module Motorsport.Analysis.RivalsTest exposing (suite)

import Expect
import Motorsport.Analysis.Rivals as Rivals
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Internal.ChangePoints as ChangePoints
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
    describe "Motorsport.Analysis.Rivals"
        [ describe "who counts as a rival"
            [ test "the classmates either side, the car of another class between them passed over" <|
                \_ ->
                    fightAround "2"
                        |> Expect.equal (Just [ "1", "2", "3" ])
            , test "the class the group was taken from is the car's own, not the field's first" <|
                \_ ->
                    rivalsAround "7"
                        |> Maybe.map Rivals.class
                        |> Expect.equal (Just (classOf "LMGT3"))
            , test "a car the running order does not hold is its own only company" <|
                \_ ->
                    fightAround "99"
                        |> Expect.equal (Just [ "99" ])
            ]
        , describe "at the edges of the class"
            [ test "the car at the front of it has only the one behind" <|
                \_ ->
                    fightAround "1"
                        |> Expect.equal (Just [ "1", "2" ])
            , test "and the car at the back only the one ahead" <|
                \_ ->
                    fightAround "4"
                        |> Expect.equal (Just [ "3", "4" ])
            ]
        , describe "how far out a reader asks"
            [ test "a wider ring comes out in running order, the car among them" <|
                \_ ->
                    rivalsAround "3"
                        |> Maybe.map (Rivals.nearest 2 >> carNumbers)
                        |> Expect.equal (Just [ "1", "2", "3", "4" ])
            , test "asking past where the class runs out gives the class, not a ring cut short" <|
                \_ ->
                    rivalsAround "2"
                        |> Maybe.map (Rivals.nearest 99 >> carNumbers)
                        |> Expect.equal (Just [ "1", "2", "3", "4" ])
            , test "the car the group was built around is the one it was given" <|
                \_ ->
                    rivalsAround "3"
                        |> Maybe.map (Rivals.focused >> .metadata >> .carNumber)
                        |> Expect.equal (Just "3")
            ]
        ]



-- FIXTURE
--
-- Four Hypercars and two GT3 cars, the two classes interleaved so that a car's
-- neighbours on the road are not its neighbours in its class. Car 99 races in
-- the same class as the four and is left out of the running order, which is
-- what a car the field does not hold reads as.


rivalsAround : String -> Maybe Rivals.Rivals
rivalsAround carNumber =
    carAt carNumber |> Maybe.map (Rivals.around field)


fightAround : String -> Maybe (List String)
fightAround carNumber =
    rivalsAround carNumber |> Maybe.map (Rivals.fight >> carNumbers)


carNumbers : List CarAt -> List String
carNumbers =
    List.map (.metadata >> .carNumber)


{-| The overall running order, as the views hand it over. `around` reads the
list as the order rather than sorting it, so this is the order under test and
not the one the snapshot arrived in.
-}
field : List CarAt
field =
    [ "1", "7", "2", "3", "8", "4" ] |> List.filterMap carAt


carAt : String -> Maybe CarAt
carAt carNumber =
    Snapshot.get carNumber grid


grid : Snapshot
grid =
    Race.fromCars { timeLimit = Instant.raceStart, index = noIndex }
        [ carOf "1" "HYPERCAR"
        , carOf "2" "HYPERCAR"
        , carOf "3" "HYPERCAR"
        , carOf "4" "HYPERCAR"
        , carOf "99" "HYPERCAR"
        , carOf "7" "LMGT3"
        , carOf "8" "LMGT3"
        ]
        |> Snapshot.at { elapsed = Instant.fromDuration 30000 }


{-| A car with two laps behind it, which is enough to be in the field. What the
laps say is not read here.
-}
carOf : String -> String -> Car
carOf carNumber class =
    { metadata = metadataOf carNumber (classOf class)
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
