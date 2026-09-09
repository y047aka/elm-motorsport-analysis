module Motorsport.Race.TimelineEventTest exposing (suite)

import Expect
import Motorsport.Wec.Class as Class
import Motorsport.Driver as Driver
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (unknown)
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "TimelineEvent.fromCars"
        [ test "empty cars produces only RaceStart" <|
            \_ ->
                let
                    events =
                        timelineOf 0 []
                in
                Expect.all
                    [ \() -> Expect.equal 1 (List.length events)
                    , \() ->
                        case List.head events of
                            Just event ->
                                Expect.all
                                    [ \_ -> Expect.equal Instant.raceStart event.eventTime
                                    , \_ -> Expect.equal RaceStart event.eventType
                                    ]
                                    ()

                            Nothing ->
                                Expect.fail "Expected RaceStart event"
                    ]
                    ()
        , test "one Start per car that took it, and none for a car with no laps" <|
            \_ ->
                timelineOf 0
                    [ carNumbered "1" [ lapAt 1 95365 ]
                    , carNumbered "2" []
                    ]
                    |> List.filterMap
                        (\event ->
                            case event.eventType of
                                CarEvent carNumber Start ->
                                    Just carNumber

                                _ ->
                                    Nothing
                        )
                    |> Expect.equal [ "1" ]
        , test "a car still out there when the flag falls takes it" <|
            \_ ->
                let
                    car =
                        carWithLaps [ lapAt 1 3500000, lapAt 2 7300000 ]
                in
                timelineOf 7200000 [ car ]
                    |> terminalEventTypes
                    |> Expect.equal [ Checkered ]
        , test "a car whose last lap is short of the flag retired" <|
            \_ ->
                let
                    car =
                        carWithLaps [ lapAt 1 3500000, lapAt 2 7100000 ]
                in
                timelineOf 7200000 [ car ]
                    |> terminalEventTypes
                    |> Expect.equal [ Retirement ]
        , test "single car with two laps produces correctly sorted events" <|
            \_ ->
                let
                    car =
                        carWithLaps [ lapAt 1 95365, lapAt 2 189575 ]

                    events =
                        timelineOf 0 [ car ]
                in
                Expect.all
                    [ \() -> Expect.atLeast 3 (List.length events)
                    , \() ->
                        case List.head events of
                            Just first ->
                                Expect.equal RaceStart first.eventType

                            Nothing ->
                                Expect.fail "Expected at least one event"
                    , \() -> Expect.equal True (isSortedAscending (List.map (.eventTime >> Instant.toDuration) events))
                    ]
                    ()
        , test "PitIn / PitOut events: timing, lap_number, duration, integrity" <|
            \_ ->
                let
                    pitDuration =
                        69953

                    laps =
                        [ lapAt 1 95365
                        , (lapAt 2 189575) |> withPitTime (Just pitDuration)
                        ]

                    car =
                        carWithLaps laps

                    events =
                        timelineOf 0 [ car ]

                    pitInEvents =
                        events
                            |> List.filterMap
                                (\e ->
                                    case e.eventType of
                                        CarEvent _ (PitIn r) ->
                                            Just ( e.eventTime, r )

                                        _ ->
                                            Nothing
                                )

                    pitOutEvents =
                        events
                            |> List.filterMap
                                (\e ->
                                    case e.eventType of
                                        CarEvent _ (PitOut r) ->
                                            Just ( e.eventTime, r )

                                        _ ->
                                            Nothing
                                )
                in
                case ( pitInEvents, pitOutEvents ) of
                    ( [ ( pitInTime, pitIn ) ], [ ( pitOutTime, pitOut ) ] ) ->
                        Expect.all
                            [ \_ -> Expect.equal 2 pitIn.lapNumber
                            , \_ -> Expect.equal pitDuration pitIn.duration
                            , \_ -> Expect.equal (Instant.fromDuration (189575 - pitDuration)) pitInTime
                            , \_ -> Expect.equal 2 pitOut.lapNumber
                            , \_ -> Expect.equal pitDuration pitOut.duration
                            , \_ -> Expect.equal (Instant.fromDuration 189575) pitOutTime
                            , \_ -> Expect.equal pitOutTime (Instant.add pitDuration pitInTime)
                            ]
                            ()

                    _ ->
                        Expect.fail "Expected exactly one PitIn and one PitOut"
        , describe "lead changes"
            [ test "a field that never changes leader produces no TookLead" <|
                \_ ->
                    [ carNumbered "1" [ leading (lapAt 1 95365), leading (lapAt 2 189575) ]
                    , carNumbered "2" [ running (lapAt 1 96000), running (lapAt 2 190000) ]
                    ]
                        |> tookLeadEvents
                        |> Expect.equal []
            , test "one event per change, timed at the new leader crossing the line" <|
                \_ ->
                    -- Car 1 leads laps 1 and 3; car 2 takes it on lap 2. Two changes.
                    [ carNumbered "1" [ leading (lapAt 1 95365), running (lapAt 2 191000), leading (lapAt 3 280000) ]
                    , carNumbered "2" [ running (lapAt 1 96000), leading (lapAt 2 189575), running (lapAt 3 281000) ]
                    ]
                        |> tookLeadEvents
                        |> Expect.equal [ ( 189575, "2" ), ( 280000, "1" ) ]
            , test "whoever leads the opening lap has taken it from nobody" <|
                \_ ->
                    [ carNumbered "1" [ leading (lapAt 1 95365) ]
                    , carNumbered "2" [ running (lapAt 1 96000) ]
                    ]
                        |> tookLeadEvents
                        |> Expect.equal []
            , test "laps with no position assigned yield no lead at all" <|
                \_ ->
                    [ carWithLaps [ unplaced (lapAt 1 95365), unplaced (lapAt 2 189575) ] ]
                        |> tookLeadEvents
                        |> Expect.equal []
            ]
        ]



-- HELPERS


carWithLaps : List Lap -> Car
carWithLaps laps =
    { metadata =
        { carNumber = "1"
        , drivers = [ Driver.fromName "Test Driver" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = unknown
        }
    , startPosition = 1
    , laps = laps
    }


lapAt : Int -> Int -> Lap
lapAt lapNumber elapsed =
    let
        base =
            Lap.empty
    in
    { base
        | carNumber = "1"
        , driver = Driver.fromName "Test Driver"
        , lap = lapNumber
        , position = Just 1
        , elapsed = Instant.fromDuration elapsed
    }


withPitTime : Maybe Int -> Lap -> Lap
withPitTime pitTime lap =
    { lap | pitTime = pitTime }


{-| `Lap.position` counts from zero, so the leader of a lap is position 0.
-}
leading : Lap -> Lap
leading lap =
    { lap | position = Just 0 }


running : Lap -> Lap
running lap =
    { lap | position = Just 1 }


{-| A lap the loader never got round to placing.
-}
unplaced : Lap -> Lap
unplaced lap =
    { lap | position = Nothing }


carNumbered : String -> List Lap -> Car
carNumbered carNumber laps =
    let
        base =
            carWithLaps laps

        metadata =
            base.metadata
    in
    { base | metadata = { metadata | carNumber = carNumber } }


{-| The timeline of a race that ran to `timeLimit`. Fixtures that do not care
where the flag fell pass nought, which puts every car past it, so no retirement
gets in the way of what they are actually about.
-}
timelineOf : Int -> List Car -> List TimelineEvent
timelineOf timeLimit cars =
    TimelineEvent.fromCars { timeLimit = Instant.fromDuration timeLimit } cars


{-| How each car's race ended.
-}
terminalEventTypes : List TimelineEvent -> List CarEventType
terminalEventTypes =
    List.filterMap
        (\event ->
            case event.eventType of
                CarEvent _ Checkered ->
                    Just Checkered

                CarEvent _ Retirement ->
                    Just Retirement

                _ ->
                    Nothing
        )


{-| Every TookLead in the timeline, as (when, who).
-}
tookLeadEvents : List Car -> List ( Int, String )
tookLeadEvents cars =
    timelineOf 0 cars
        |> List.filterMap
            (\event ->
                case event.eventType of
                    CarEvent carNumber TookLead ->
                        Just ( Instant.toDuration event.eventTime, carNumber )

                    _ ->
                        Nothing
            )


isSortedAscending : List Int -> Bool
isSortedAscending xs =
    case xs of
        [] ->
            True

        _ :: [] ->
            True

        a :: b :: rest ->
            a <= b && isSortedAscending (b :: rest)
