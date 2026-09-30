module Motorsport.Analysis.CarLogTest exposing (suite)

import Expect
import Motorsport.Analysis.CarLog as CarLog
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Flag exposing (Flag(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Wec.Class as Class
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.CarLog"
        [ describe "the events"
            [ test "one car's own, newest first, in the words the field prints them in" <|
                \_ ->
                    Timeline.fromList
                        [ event 0 RaceStart
                        , event 60000 (CarEvent "7" OvertakeForLead)
                        , event 90000 (CarEvent "8" OvertakeForLead)
                        , event 120000 (CarEvent "7" Retired)
                        ]
                        |> CarLog.lines (clock 200000) (carWith [ lapAt 1 60000 ])
                        |> List.map (\line -> ( line.lap, line.label ))
                        |> Expect.equal [ ( 1, "Retired" ), ( 1, "Overtake for Lead" ) ]
            , test "the field's events are nobody's, and so is a leader in the pits" <|
                \_ ->
                    Timeline.fromList
                        [ event 0 RaceStart
                        , event 60000 (Flag FullCourseYellow)
                        , event 90000 (CarEvent "7" LeaderInPit)
                        ]
                        |> CarLog.lines (clock 200000) (carWith [ lapAt 1 60000 ])
                        |> Expect.equal []
            , test "an event before the car turned its first lap stands at lap 0" <|
                \_ ->
                    Timeline.fromList [ event 30000 (CarEvent "7" Retired) ]
                        |> CarLog.lines (clock 200000) (carWith [])
                        |> List.map (\line -> ( line.lap, line.label ))
                        |> Expect.equal [ ( 0, "Retired" ) ]
            , test "a fastest lap is told as the lap it completed" <|
                \_ ->
                    Timeline.fromList [ event 60000 (CarEvent "7" FastestLap) ]
                        |> CarLog.lines (clock 100000) (carWith [ improved 1 60000 60000 ])
                        |> Expect.all
                            [ List.map .lap >> Expect.equal [ 1, 1 ]
                            , List.map .label >> Expect.equal [ "1:00.000", "1:00.000" ]
                            , List.map .by >> Expect.equal [ Just "K.KOBAYASHI", Just "K.KOBAYASHI" ]
                            , List.map .level >> Expect.equal [ Performance.Fastest, Performance.PersonalBest ]
                            ]
            , test "a driver change names the two drivers and the lap it fell on" <|
                \_ ->
                    Timeline.fromList [ event 60000 (CarEvent "7" DriverChange) ]
                        |> CarLog.lines
                            (clock 200000)
                            (carWith [ lapAt 1 60000, lapAt 2 120000 |> drivenBy conway ])
                        |> List.map (\line -> ( line.lap, line.label, line.by ))
                        |> Expect.equal [ ( 1, "K.KOBAYASHI → M.CONWAY", Nothing ) ]
            ]
        , describe "the laps"
            [ test "a stop is told as the lap the car crossed into the lane on" <|
                \_ ->
                    [ lapAt 1 60000
                    , lapAt 2 243000 |> timed 55000
                    , lapAt 3 313000 |> timed 70000 |> outOfLane 70000
                    ]
                        |> announcedBy 400000
                        |> List.map (\line -> ( line.lap, line.label ))
                        |> Expect.equal [ ( 2, "Pit" ) ]
            , test "a stop the car never came out of has no lane time to tell" <|
                \_ ->
                    [ lapAt 1 60000, lapAt 2 300000 |> timed 55000 |> intoLane ]
                        |> announcedBy 400000
                        |> Expect.equal []
            , test "the laps that improved the car's own best, newest first" <|
                \_ ->
                    [ improved 1 60000 60000
                    , lapAt 2 120000 |> timed 61000 |> bestSoFar 60000
                    , improved 3 59000 180000
                    ]
                        |> announcedBy 400000
                        |> List.map (\line -> ( line.lap, line.label, line.level ))
                        |> Expect.equal
                            [ ( 3, "59.000", Performance.PersonalBest )
                            , ( 1, "1:00.000", Performance.PersonalBest )
                            ]
            , test "a lap the clock has not run makes no line" <|
                \_ ->
                    [ improved 1 60000 60000
                    , lapAt 2 120000 |> timed 61000 |> bestSoFar 60000
                    , improved 3 59000 180000
                    ]
                        |> announcedBy 150000
                        |> List.map (\line -> ( line.lap, line.label ))
                        |> Expect.equal [ ( 1, "1:00.000" ) ]
            ]
        , describe "the order"
            [ test "events lead their laps, and a crossing is told before the lap it ended" <|
                \_ ->
                    Timeline.fromList [ event 250000 (CarEvent "7" OvertakeForLead) ]
                        |> CarLog.lines
                            (clock 400000)
                            (carWith
                                [ improved 1 60000 60000
                                , improved 2 55000 243000
                                , lapAt 3 313000 |> timed 70000 |> bestSoFar 55000 |> outOfLane 70000
                                ]
                            )
                        |> List.map .label
                        |> Expect.equal [ "Overtake for Lead", "Pit", "55.000", "1:00.000" ]
            ]
        ]



-- FIXTURES


{-| The car's lines with nothing announced about it, so the only ones there are
come from its laps.
-}
announcedBy : Int -> List Lap -> List CarLog.Line
announcedBy ms laps =
    CarLog.lines (clock ms) (carWith laps) Timeline.empty


clock : Int -> { elapsed : Instant }
clock ms =
    { elapsed = Instant.fromDuration ms }


instant : Int -> Instant
instant =
    Instant.fromDuration


event : Int -> EventType -> TimelineEvent
event ms eventType =
    { elapsed = instant ms, eventType = eventType }


{-| A lap the feed left untimed: what a lap the car is still driving reads as.
-}
lapAt : Int -> Int -> Lap
lapAt lapNumber elapsed =
    { empty | lap = lapNumber, elapsed = instant elapsed }


timed : Int -> Lap -> Lap
timed time lap =
    { lap | time = Just time }


bestSoFar : Int -> Lap -> Lap
bestSoFar best lap =
    { lap | best = Just best }


{-| A lap that improved the car's own best: the feed carries its time as the best
running to and including it.
-}
improved : Int -> Int -> Int -> Lap
improved lapNumber time elapsed =
    lapAt lapNumber elapsed |> timed time |> bestSoFar time


intoLane : Lap -> Lap
intoLane lap =
    { lap | pit = Lap.InLap }


outOfLane : Int -> Lap -> Lap
outOfLane laneTime lap =
    { lap | pit = Lap.OutLap laneTime }


drivenBy : Driver -> Lap -> Lap
drivenBy driver lap =
    { lap | driver = driver }


carWith : List Lap -> Car
carWith laps =
    { metadata =
        { carNumber = "7"
        , drivers = [ kobayashi, conway ]
        , class = Class.none
        , group = "H"
        , team = "Toyota Racing"
        , manufacturer = Manufacturer.unknown
        , imageUrl = Nothing
        }
    , startPosition = 1
    , laps = laps
    }


kobayashi : Driver
kobayashi =
    Driver.fromName "Kamui KOBAYASHI"


conway : Driver
conway =
    Driver.fromName "Mike CONWAY"


empty : Lap
empty =
    let
        base =
            Lap.empty
    in
    { base | carNumber = "7", driver = kobayashi }
