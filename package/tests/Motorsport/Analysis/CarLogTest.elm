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
                        |> Expect.equal [ ( Just 1, "Retired" ), ( Just 1, "Overtake for Lead" ) ]
            , test "the field's events are nobody's, and so is a leader in the pits" <|
                \_ ->
                    Timeline.fromList
                        [ event 0 RaceStart
                        , event 60000 (Flag FullCourseYellow)
                        , event 90000 (CarEvent "7" LeaderInPit)
                        ]
                        |> CarLog.lines (clock 200000) (carWith [ lapAt 1 60000 ])
                        |> Expect.equal []
            , test "an event before the car turned its first lap has no lap to name" <|
                \_ ->
                    Timeline.fromList [ event 30000 (CarEvent "7" Retired) ]
                        |> CarLog.lines (clock 200000) (carWith [])
                        |> List.map (\line -> ( line.lap, line.label ))
                        |> Expect.equal [ ( Nothing, "Retired" ) ]
            , test "the race's record is left to the lap that set it" <|
                \_ ->
                    -- The record's event and the lap's own line name 60000 and
                    -- 1:00.000 both, so one of them is kept: the lap's.
                    Timeline.fromList [ event 60000 (CarEvent "7" FastestLap) ]
                        |> CarLog.lines (clock 100000) (carWith [ improved 1 60000 60000 ])
                        |> Expect.all
                            [ List.map .lap >> Expect.equal [ Just 1 ]
                            , List.map .label >> Expect.equal [ "1:00.000" ]
                            , List.map .by >> Expect.equal [ Just "K.KOBAYASHI" ]
                            , List.map .level >> Expect.equal [ Performance.Fastest ]
                            ]
            , test "each record keeps the rating it took, whichever lap broke it next" <|
                \_ ->
                    -- Lap 2 is the record at 120000 and lap 1 was the record at
                    -- 60000, so both lines are rated as records although only one
                    -- of them is the record the clock stands on.
                    Timeline.fromList
                        [ event 60000 (CarEvent "7" FastestLap)
                        , event 120000 (CarEvent "7" FastestLap)
                        ]
                        |> CarLog.lines
                            (clock 200000)
                            (carWith [ improved 1 60000 60000, improved 2 55000 120000 ])
                        |> List.map (\line -> ( line.lap, line.level ))
                        |> Expect.equal [ ( Just 2, Performance.Fastest ), ( Just 1, Performance.Fastest ) ]
            , test "a record the car's laps did not improve is the feed's to tell" <|
                \_ ->
                    -- No lap of this car crossed the line at 60000 having improved
                    -- its best, so nothing of the car's tells the record.
                    Timeline.fromList [ event 60000 (CarEvent "7" FastestLap) ]
                        |> CarLog.lines
                            (clock 100000)
                            (carWith [ lapAt 1 60000 |> timed 61000 |> bestSoFar 60000 ])
                        |> List.map (\line -> ( line.lap, line.label, line.level ))
                        |> Expect.equal [ ( Just 1, "1:01.000", Performance.Fastest ) ]
            , test "a driver change names the two drivers and the lap it fell on" <|
                \_ ->
                    Timeline.fromList [ event 60000 (CarEvent "7" DriverChange) ]
                        |> CarLog.lines
                            (clock 200000)
                            (carWith [ lapAt 1 60000, lapAt 2 120000 |> drivenBy conway ])
                        |> List.map (\line -> ( line.lap, line.label, line.by ))
                        |> Expect.equal [ ( Just 1, "K.KOBAYASHI → M.CONWAY", Nothing ) ]
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
                        |> Expect.equal [ ( Just 2, "Pit" ) ]
            , test "a stop whose in-lap the laps do not hold names the last one completed before the crossing" <|
                \_ ->
                    -- The crossing into the lane is at 243.000, where lap 2
                    -- would have ended but does not exist; the laps can only
                    -- say the car was on lap 1 when it arrived.
                    [ lapAt 1 100000
                    , lapAt 3 313000 |> timed 70000 |> outOfLane 70000
                    ]
                        |> announcedBy 400000
                        |> List.map (\line -> ( line.lap, line.label ))
                        |> Expect.equal [ ( Just 1, "Pit" ) ]
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
                            [ ( Just 3, "59.000", Performance.PersonalBest )
                            , ( Just 1, "1:00.000", Performance.PersonalBest )
                            ]
            , test "a lap the clock has not run makes no line" <|
                \_ ->
                    [ improved 1 60000 60000
                    , lapAt 2 120000 |> timed 61000 |> bestSoFar 60000
                    , improved 3 59000 180000
                    ]
                        |> announcedBy 150000
                        |> List.map (\line -> ( line.lap, line.label ))
                        |> Expect.equal [ ( Just 1, "1:00.000" ) ]
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
    { lap | crossing = Lap.EntryAtEnd }


outOfLane : Int -> Lap -> Lap
outOfLane laneTime lap =
    { lap | crossing = Lap.ExitAtStart laneTime }


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
