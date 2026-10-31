module Motorsport.Chart.LapTimeDistributionTest exposing (suite)

import Expect
import Internal.ChangePoints as ChangePoints
import Motorsport.BestTimes as BestTimes
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.LapRange exposing (LapRange)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race as Race
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


{-| `sharedBounds` draws one lap-time axis over the cars of a class. What is
owed to the reader is that the axis spans every lap of the set the fence leaves,
that it spans each car's own range and no more, and that a car with nothing to
describe neither gets an axis of its own nor costs the class one.
-}
suite : Test
suite =
    describe "Motorsport.Chart.LapTimeDistribution"
        [ describe "sharedBounds"
            [ test "the axis spans every car's times, not merely the first car's" <|
                \_ ->
                    case
                        ( boundsOf [ ( "10", full ), ( "11", full ) ]
                        , boundsOf [ ( "10", full ) ]
                        , boundsOf [ ( "11", full ) ]
                        )
                    of
                        ( Just shared, Just onlyTen, Just onlyEleven ) ->
                            let
                                ( lo, hi ) =
                                    shared.domain
                            in
                            Expect.all
                                [ \_ -> Expect.atMost (Tuple.first onlyTen.domain) lo
                                , \_ -> Expect.atMost (Tuple.first onlyEleven.domain) lo
                                , \_ -> Expect.atLeast (Tuple.second onlyTen.domain) hi
                                , \_ -> Expect.atLeast (Tuple.second onlyEleven.domain) hi
                                ]
                                ()

                        _ ->
                            Expect.fail "every car here has timed laps"
            , test "a car with no completed lap joins the set without moving its axis" <|
                \_ ->
                    Expect.equal
                        (boundsOf [ ( "10", full ) ])
                        (boundsOf [ ( "10", full ), ( "99", full ) ])
            , test "a lap outside a car's own range is off the shared axis too" <|
                \_ ->
                    -- Car 11's third lap is the slowest of the set; cutting it
                    -- out of that car's range has to pull the shared top of the
                    -- axis with it.
                    case
                        ( boundsOf [ ( "10", full ), ( "11", full ) ]
                        , boundsOf [ ( "10", full ), ( "11", { first = 1, last = 2 } ) ]
                        )
                    of
                        ( Just wide, Just narrow ) ->
                            Expect.greaterThan (Tuple.second narrow.domain) (Tuple.second wide.domain)

                        _ ->
                            Expect.fail "both sets hold timed laps"
            , test "a range holding no lap yields no axis at all" <|
                \_ ->
                    Expect.equal Nothing (boundsOf [ ( "10", { first = 1, last = 0 } ) ])
            ]
        , describe "the fence the shared axis is drawn over"
            [ test "one car's wide race does not set the axis the class is drawn on" <|
                \_ ->
                    -- #11 ran three laps at the class's pace and three half a
                    -- minute down it, and its own fence is wide enough to let all
                    -- six through. The class's fence is drawn over both cars, and
                    -- the axis ends with the laps that survive it.
                    case boundsOfOn wideRaced [ ( "10", twelve ), ( "11", six ) ] of
                        Just { domain } ->
                            Expect.lessThan 130000 (Tuple.second domain)

                        Nothing ->
                            Expect.fail "both cars have timed laps"
            , test "the axis still spans every lap the fence leaves" <|
                -- The fence is not there to trim the field's own spread: the
                -- slowest lap it keeps is inside the axis, not just off the end
                -- of a curve nobody can read to.
                \_ ->
                    case boundsOfOn wideRaced [ ( "10", twelve ), ( "11", six ) ] of
                        Just { domain } ->
                            Expect.atLeast 101100 (Tuple.second domain)

                        Nothing ->
                            Expect.fail "both cars have timed laps"
            ]
        , describe "a set too small to hold an outlier"
            [ test "the slower of two opening laps is not its own outlier" <|
                -- Two cars with one lap each is the whole of the set at the end
                -- of lap 1. Four laps is where quartiles separate anything at
                -- all, so below that the fence is the maximum and both cars
                -- draw; were it not, the slower car's row would be blank at the
                -- moment the column is read most.
                \_ ->
                    case boundsOfOn opening [ ( "30", one ), ( "31", one ) ] of
                        Just { domain } ->
                            Expect.atLeast 104000 (Tuple.second domain)

                        Nothing ->
                            Expect.fail "both cars have a timed lap"
            ]
        ]



-- FIXTURE
--
-- Three cars: two that ran three timed laps each, the second some three
-- seconds a lap off the first, with every lap close enough to its car's own
-- pace to survive the outlier fence, and a third whose only lap runs past the
-- clock the race is read at, so its history holds nothing.


full : LapRange
full =
    { first = 1, last = 3 }


boundsOf : List ( String, LapRange ) -> Maybe LapTimeDistribution.Bounds
boundsOf entries =
    boundsOfOn snapshot entries


boundsOfOn : Snapshot -> List ( String, LapRange ) -> Maybe LapTimeDistribution.Bounds
boundsOfOn race entries =
    entries
        |> List.filterMap
            (\( carNumber, range ) ->
                Maybe.map (\car -> { range = range, car = car }) (Snapshot.get carNumber race)
            )
        |> LapTimeDistribution.sharedBounds (Snapshot.lapHistory race)


snapshot : Snapshot
snapshot =
    Race.fromCars { timeLimit = Instant.raceStart, index = noIndex }
        [ carOf "10" 60000 [ 100000, 100200, 100350 ]
        , carOf "11" 60000 [ 103000, 103400, 103700 ]
        , carOf "99" 500000 [ 120000 ]
        ]
        |> Snapshot.at { elapsed = Instant.fromDuration 400000 }


{-| Two cars of one class over the opening of a race: #10 held one pace for
 twelve laps, #11 ran three at that pace and three some half a minute down it.
-}
wideRaced : Snapshot
wideRaced =
    Race.fromCars { timeLimit = Instant.raceStart, index = noIndex }
        [ carOf "10" 20000 (List.range 0 11 |> List.map (\i -> 100000 + i * 100))
        , carOf "11" 40000 [ 100050, 100150, 100250, 130000, 131000, 132000 ]
        ]
        |> Snapshot.at { elapsed = Instant.fromDuration 400000 }


twelve : LapRange
twelve =
    { first = 1, last = 12 }


six : LapRange
six =
    { first = 1, last = 6 }


{-| The end of the first lap of a class of two.
-}
opening : Snapshot
opening =
    Race.fromCars { timeLimit = Instant.raceStart, index = noIndex }
        [ carOf "30" 60000 [ 100000 ]
        , carOf "31" 60000 [ 104000 ]
        ]
        |> Snapshot.at { elapsed = Instant.fromDuration 400000 }


one : LapRange
one =
    { first = 1, last = 1 }


carOf : String -> Duration -> List Duration -> Car
carOf carNumber lapLength times =
    { metadata = metadataOf carNumber
    , startPosition = 1
    , laps =
        times
            |> List.indexedMap
                (\index time ->
                    { emptyLap
                        | carNumber = carNumber
                        , driver = Driver.fromName ("Driver " ++ carNumber)
                        , lap = index + 1
                        , time = Just time
                        , elapsed = Instant.fromDuration (lapLength * (index + 1))
                    }
                )
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
    , flagChanges = ChangePoints.empty
    }


metadataOf : String -> Car.Metadata
metadataOf carNumber =
    { carNumber = carNumber
    , drivers = [ Driver.fromName ("Driver " ++ carNumber) ]
    , class = Class.fromString Era.Gt3AsThirdClass "HYPERCAR"
    , group = "H"
    , team = "Team " ++ carNumber
    , manufacturer = Manufacturer.unknown
    , imageUrl = Nothing
    }
