module Motorsport.RaceTest exposing (suite)

import Expect
import Internal.ChangePoints as ChangePoints
import Motorsport.BestTimes as BestTimes
import Json.Decode as Decode
import Motorsport.Driver as Driver
import Motorsport.Flag exposing (Flag(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (unknown)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car exposing (Car, CarNumber)
import Motorsport.Status as Status
import Motorsport.Wec.Class as Class
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
        , describe "lapTotal"
            [ test "is the ceiling lapCountAt can actually reach" <|
                \_ ->
                    -- Both come off lapCompletions, so they cannot disagree.
                    Race.lapCountAt { elapsed = instant 99999999 } race
                        |> Expect.equal race.lapTotal
            ]
        , describe "timeToFlagAt"
            -- The fixture's flag falls at 7200000, well past its last lap.
            [ test "counts down to the flag" <|
                \_ ->
                    [ 0, 7199999 ]
                        |> List.map (\elapsed -> Race.timeToFlagAt { elapsed = instant elapsed } race)
                        |> Expect.equal [ 7200000, 1 ]
            , test "and has nothing left to count once it has fallen" <|
                \_ ->
                    -- The race is still readable here: it goes on being run
                    -- after the flag, on a lap already under way.
                    [ 7200000, 99999999 ]
                        |> List.map (\elapsed -> Race.timeToFlagAt { elapsed = instant elapsed } race)
                        |> Expect.equal [ 0, 0 ]
            ]
        , describe "flagPeriods"
            [ test "each flag lasts until the next one, and the last one is open" <|
                \_ ->
                    Race.flagPeriods flagged
                        |> List.map (\p -> ( p.flag, Instant.toDuration p.from, Maybe.map Instant.toDuration p.until ))
                        |> Expect.equal
                            [ ( FullCourseYellow, 100000, Just 150000 )
                            , ( SafetyCar, 150000, Just 250000 )
                            , ( GreenFlag, 250000, Just 350000 )
                            , ( RedFlag, 350000, Nothing )
                            ]
            , test "a race no flag was shown in has no periods" <|
                \_ ->
                    Race.flagPeriods race
                        |> Expect.equal []
            ]
        , describe "flagAt"
            [ test "green before any flag has been shown" <|
                \_ ->
                    Race.flagAt { elapsed = instant 99999 } flagged
                        |> Expect.equal GreenFlag
            , test "a flag holds from the instant it is shown" <|
                \_ ->
                    [ 100000, 149999, 150000, 250000, 350000, 9999999 ]
                        |> List.map (\elapsed -> Race.flagAt { elapsed = instant elapsed } flagged)
                        |> Expect.equal [ FullCourseYellow, FullCourseYellow, SafetyCar, GreenFlag, RedFlag, RedFlag ]
            ]
        , describe "indexDecoder"
            [ test "reads the flag changes the summary spells" <|
                \_ ->
                    Decode.decodeString Race.indexDecoder (indexJson "safetyCar")
                        |> Result.map (.flagChanges >> ChangePoints.toList >> List.map (Tuple.mapFirst Instant.toDuration))
                        |> Expect.equal (Ok [ ( 60000, SafetyCar ) ])
            , test "a flag it has no name for fails the index rather than reading as green" <|
                \_ ->
                    Decode.decodeString Race.indexDecoder (indexJson "SF")
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            ]
        , describe "pitStopsAt"
            [ test "counts the stops off the cars the race was built from" <|
                \_ ->
                    let
                        raced =
                            Race.fromCars
                                { timeLimit = instant 7200000
                                , index = index
                                }
                                [ carWith "1" [ lapAt "1" 1 100000, pitAt "1" 2 260000 160000 63000 ] ]
                    in
                    [ 162999, 163000 ]
                        |> List.map (\elapsed -> Race.pitStopsAt { elapsed = instant elapsed } "1" raced)
                        |> Expect.equal [ 0, 1 ]
            , test "the fixture's cars never stopped" <|
                \_ ->
                    Race.pitStopsAt { elapsed = instant 99999999 } "1" race
                        |> Expect.equal 0
            , test "a race with no cars has no stops" <|
                \_ ->
                    Race.pitStopsAt { elapsed = instant 500000 } "1" Race.empty
                        |> Expect.equal 0
            ]
        , describe "statusAt"
            [ test "a car is running until its final crossing" <|
                \_ ->
                    [ 0, 299999, 300000 ]
                        |> List.map (\at -> Race.statusAt { elapsed = instant at } carOne race)
                        |> Expect.equal [ Status.Racing, Status.Racing, Status.Retired ]
            , test "a car still running when the race was scheduled to end took the flag" <|
                \_ ->
                    Race.statusAt { elapsed = instant 99999999 } carTwo race
                        |> Expect.equal Status.Checkered
            , test "a car that turned no lap never started" <|
                \_ ->
                    Race.statusAt { elapsed = instant 99999999 } (carWith "3" []) race
                        |> Expect.equal Status.PreRace
            ]
        ]



-- FIXTURE
-- Car 2 leads the first lap and then falls a long way back; car 1 goes on to
-- three laps, so the counter follows whoever is in front at the time: lap 1 at
-- car 2's 90.000, then car 1's laps 2 and 3.


race : Race
race =
    Race.fromCars { timeLimit = Instant.fromDuration 7200000, index = index } [ carOne, carTwo ]


{-| Three laps and then nothing, well short of the two hours the race was
scheduled for.
-}
carOne : Car
carOne =
    carWith "1"
        [ lapAt "1" 1 100000
        , lapAt "1" 2 200000
        , lapAt "1" 3 300000
        ]


{-| Still out there when the limit fell, which is what puts its last crossing
past it.
-}
carTwo : Car
carTwo =
    carWith "2"
        [ lapAt "2" 1 90000
        , lapAt "2" 2 7300000
        ]


{-| A yellow turned into a safety car with no green between them, then a red
that is never lifted.
-}
flagged : Race
flagged =
    Race.fromCars
        { timeLimit = instant 7200000
        , index =
            { index
                | flagChanges =
                    ChangePoints.fromList
                        [ ( instant 100000, FullCourseYellow )
                        , ( instant 150000, SafetyCar )
                        , ( instant 250000, GreenFlag )
                        , ( instant 350000, RedFlag )
                        ]
            }
        }
        []


indexJson : String -> String
indexJson flag =
    """{ "lapCompletions": [], "bestTimeChanges": { "fastestLapTime": [], "sectors": { "s1": [], "s2": [], "s3": [] }, "miniSectors": { "scl2": [], "z4": [], "ip1": [], "z12": [], "sclc": [], "a7_1": [], "ip2": [], "a8_1": [], "sclb": [], "porin": [], "porout": [], "pitref": [], "scl1": [], "fordout": [], "fl": [] } }, "flagChanges": [ { "elapsed": "1:00.000", "flag": """
        ++ ("\"" ++ flag ++ "\" } ] }")


{-| The indices the round is read with, as `Round.Index` counts them out of the
rows.
-}
index : Race.Index
index =
    { lapCompletions =
        ChangePoints.fromList
            [ ( instant 90000, 1 )
            , ( instant 200000, 2 )
            , ( instant 300000, 3 )
            ]
    , bestTimeChanges = BestTimes.empty
    , flagChanges = ChangePoints.empty
    }


carWith : CarNumber -> List Lap -> Car
carWith carNumber laps =
    { metadata =
        { carNumber = carNumber
        , drivers = [ Driver.fromName "Test Driver" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = unknown
        , imageUrl = Nothing
        }
    , startPosition = 1
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


pitAt : CarNumber -> Int -> Int -> Int -> Int -> Lap
pitAt carNumber lapNumber elapsed time pitTime =
    let
        base =
            lapAt carNumber lapNumber elapsed
    in
    { base | time = Just time, pit = Lap.OutLap pitTime }
