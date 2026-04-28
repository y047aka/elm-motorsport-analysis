module Motorsport.TimelineEventTest exposing (suite)

import Expect
import Motorsport.Car exposing (Car, Status(..))
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (Manufacturer(..))
import Motorsport.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "TimelineEvent.fromCars"
        [ test "empty cars produces only RaceStart" <|
            \_ ->
                let
                    events =
                        TimelineEvent.fromCars []
                in
                Expect.all
                    [ \() -> Expect.equal 1 (List.length events)
                    , \() ->
                        case List.head events of
                            Just event ->
                                Expect.all
                                    [ \_ -> Expect.equal 0 event.eventTime
                                    , \_ -> Expect.equal RaceStart event.eventType
                                    ]
                                    ()

                            Nothing ->
                                Expect.fail "Expected RaceStart event"
                    ]
                    ()
        , test "calcTimeLimit rounds down to whole hours (short race -> 0)" <|
            \_ ->
                let
                    car =
                        carWithLaps [ lapAt 1 95365, lapAt 2 189575 ]

                    events =
                        TimelineEvent.fromCars [ car ]

                    -- final lap elapsed = 189575 < 3600000, so terminal event is Retirement
                    terminal =
                        events
                            |> List.filter
                                (\e ->
                                    case e.eventType of
                                        CarEvent _ Retirement ->
                                            True

                                        _ ->
                                            False
                                )
                in
                Expect.equal 1 (List.length terminal)
        , test "calcTimeLimit rounds 2.5h to 2h (Checkered branch)" <|
            \_ ->
                let
                    -- 2.5h = 9_000_000 ms. Rounded down to 7_200_000 (2h) = timeLimit.
                    -- final lap elapsed = 9_000_000 >= 7_200_000 => Checkered.
                    car =
                        carWithLaps [ lapAt 1 9000000 ]

                    events =
                        TimelineEvent.fromCars [ car ]

                    checkered =
                        events
                            |> List.filter
                                (\e ->
                                    case e.eventType of
                                        CarEvent _ Checkered ->
                                            True

                                        _ ->
                                            False
                                )
                in
                Expect.equal 1 (List.length checkered)
        , test "single car with two laps produces correctly sorted events" <|
            \_ ->
                let
                    car =
                        carWithLaps [ lapAt 1 95365, lapAt 2 189575 ]

                    events =
                        TimelineEvent.fromCars [ car ]
                in
                Expect.all
                    [ \() -> Expect.atLeast 3 (List.length events)
                    , \() ->
                        case List.head events of
                            Just first ->
                                Expect.equal RaceStart first.eventType

                            Nothing ->
                                Expect.fail "Expected at least one event"
                    , \() -> Expect.equal True (isSortedAscending (List.map .eventTime events))
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
                        TimelineEvent.fromCars [ car ]

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
                            , \_ -> Expect.equal (189575 - pitDuration) pitInTime
                            , \_ -> Expect.equal 2 pitOut.lapNumber
                            , \_ -> Expect.equal pitDuration pitOut.duration
                            , \_ -> Expect.equal 189575 pitOutTime
                            , \_ -> Expect.equal pitOutTime (pitInTime + pitDuration)
                            ]
                            ()

                    _ ->
                        Expect.fail "Expected exactly one PitIn and one PitOut"
        , test "embedded laps in Start / LapCompleted have pitTime stripped" <|
            \_ ->
                let
                    pitDuration =
                        69953

                    laps =
                        [ (lapAt 1 95365) |> withPitTime (Just pitDuration)
                        , (lapAt 2 189575) |> withPitTime (Just pitDuration)
                        ]

                    car =
                        carWithLaps laps

                    events =
                        TimelineEvent.fromCars [ car ]

                    embeddedPitTimes =
                        events
                            |> List.filterMap
                                (\e ->
                                    case e.eventType of
                                        CarEvent _ (Start { currentLap }) ->
                                            Just currentLap.pitTime

                                        CarEvent _ (LapCompleted _ { nextLap }) ->
                                            Just nextLap.pitTime

                                        _ ->
                                            Nothing
                                )
                in
                Expect.equal True (List.all ((==) Nothing) embeddedPitTimes)
        ]



-- HELPERS


carWithLaps : List Lap -> Car
carWithLaps laps =
    { metadata =
        { carNumber = "1"
        , drivers = [ Driver "Test Driver" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = Other
        }
    , startPosition = 1
    , laps = laps
    , currentLap = Nothing
    , lastLap = Nothing
    , status = PreRace
    , currentDriver = Nothing
    }


lapAt : Int -> Int -> Lap
lapAt lapNumber elapsed =
    let
        base =
            Lap.empty
    in
    { base
        | carNumber = "1"
        , driver = Driver "Test Driver"
        , lap = lapNumber
        , position = Just 1
        , elapsed = elapsed
    }


withPitTime : Maybe Int -> Lap -> Lap
withPitTime pitTime lap =
    { lap | pitTime = pitTime }


isSortedAscending : List Int -> Bool
isSortedAscending xs =
    case xs of
        [] ->
            True

        _ :: [] ->
            True

        a :: b :: rest ->
            a <= b && isSortedAscending (b :: rest)
