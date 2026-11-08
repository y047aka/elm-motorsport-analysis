module Motorsport.Chart.LapDeltaTest exposing (suite)

import Expect
import Internal.ChangePoints as ChangePoints
import Motorsport.BestTimes as BestTimes
import Motorsport.Chart.LapDelta as LapDelta
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


{-| `sharedBounds` draws one lap-to-lap axis over the cars of a set. What is
owed is that the fence belongs to the set -- one car's incident does not get
its own fence -- that the fence is the set's tight one, and that the axis
spans exactly the laps that survive it.
-}
suite : Test
suite =
    describe "Motorsport.Chart.LapDelta"
        [ describe "sharedBounds"
            [ test "the fence is pooled: one car's held lap does not fence itself out alone" <|
                \_ ->
                    -- #10 ran twelve laps at its own pace; #11 ran the same
                    -- pace and one lap half a minute down it. Pooled, that
                    -- lap is the set's outlier and leaves the axis; a fence
                    -- per car would have kept it, since it is all #11 has.
                    case
                        ( domainOf wideRaced [ ( "10", twelve ), ( "11", twelve ) ]
                        , domainOf wideRaced [ ( "11", twelve ) ]
                        )
                    of
                        ( Just shared, Just alone ) ->
                            Expect.all
                                [ \_ ->
                                    Expect.atMost (Tuple.first alone) (Tuple.first shared)

                                -- Pooled, the slow lap is off the axis: the
                                -- shared top sits below it.
                                , \_ ->
                                    Expect.lessThan 130000 (Tuple.second shared)
                                ]
                                ()

                        _ ->
                            Expect.fail "both cars have timed laps"
            , test "the tight fence cuts what the distribution chart's would keep" <|
                \_ ->
                    -- The five clean laps span 100.000-100.400 and the sixth
                    -- is 102.000: Q3+1.5xIQR keeps it, Q3+0.25xIQR does not,
                    -- so the axis ends below it while the kept laps stand inside it.
                    case domainOf tightFence [ ( "20", six ) ] of
                        Just ( lo, hi ) ->
                            Expect.all
                                [ \_ -> Expect.atMost 100000 lo
                                , \_ -> Expect.lessThan 102000 hi
                                , \_ -> Expect.atLeast 100300 hi
                                ]
                                ()

                        Nothing ->
                            Expect.fail "the car has timed laps"
            , test "no time at all yields no axis" <|
                \_ ->
                    domainOf openedTooEarly [ ( "30", twelve ) ]
                        |> Expect.equal Nothing
            ]
        ]


domainOf : Snapshot -> List ( String, LapRange ) -> Maybe ( Float, Float )
domainOf race entries =
    entries
        |> List.filterMap
            (\( carNumber, range ) ->
                Maybe.map (\car -> { range = range, car = car }) (Snapshot.get carNumber race)
            )
        |> LapDelta.sharedBounds (Snapshot.lapHistory race)
        |> Maybe.map .domain


{-| #10 held one pace for twelve laps; #11 ran that pace and one lap some
half a minute down.
-}
wideRaced : Snapshot
wideRaced =
    raced
        [ carOf "10" 20000 (List.range 0 11 |> List.map (\i -> 100000 + i * 100))
        , carOf "11" 40000 [ 100050, 100150, 100250, 100350, 100450, 130000 ]
        ]


{-| One car: five laps inside four tenths and one two seconds down.
-}
tightFence : Snapshot
tightFence =
    raced
        [ carOf "20" 20000 [ 100000, 100100, 100200, 100300, 100400, 102000 ]
        ]


openedTooEarly : Snapshot
openedTooEarly =
    raced [ carOf "30" 60000 [] ]


raced : List Car -> Snapshot
raced cars =
    Race.fromCars { timeLimit = Instant.raceStart, index = noIndex } cars
        |> Snapshot.at { elapsed = Instant.fromDuration 400000 }


twelve : LapRange
twelve =
    { first = 1, last = 12 }


six : LapRange
six =
    { first = 1, last = 6 }


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
