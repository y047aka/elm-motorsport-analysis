module Motorsport.TimelineEventTest exposing (suite)

import Expect
import Motorsport.Class as Class
import Motorsport.Driver as Driver
import Motorsport.Entrant exposing (Entrant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (Manufacturer(..))
import Motorsport.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "TimelineEvent.fromEntrants"
        [ test "empty cars produces only RaceStart" <|
            \_ ->
                let
                    events =
                        TimelineEvent.fromEntrants []
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
                        TimelineEvent.fromEntrants [ car ]

                    -- timeLimit = (189575 // 3600000) * 3600000 = 0
                    -- final_lap.elapsed = 189575 >= 0, so terminal event is Checkered
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
        , test "calcTimeLimit rounds 2.5h to 2h (Checkered branch)" <|
            \_ ->
                let
                    -- 2.5h = 9_000_000 ms. Rounded down to 7_200_000 (2h) = timeLimit.
                    -- final lap elapsed = 9_000_000 >= 7_200_000 => Checkered.
                    car =
                        carWithLaps [ lapAt 1 9000000 ]

                    events =
                        TimelineEvent.fromEntrants [ car ]

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
                        TimelineEvent.fromEntrants [ car ]
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
                        TimelineEvent.fromEntrants [ car ]

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
        , test "the lap embedded in Start has pitTime stripped" <|
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
                        TimelineEvent.fromEntrants [ car ]

                    embeddedPitTimes =
                        events
                            |> List.filterMap
                                (\e ->
                                    case e.eventType of
                                        CarEvent _ (Start { currentLap }) ->
                                            Just currentLap.pitTime

                                        _ ->
                                            Nothing
                                )
                in
                Expect.equal True (List.all ((==) Nothing) embeddedPitTimes)
        ]



-- HELPERS


carWithLaps : List Lap -> Entrant
carWithLaps laps =
    { metadata =
        { carNumber = "1"
        , drivers = [ Driver.fromName "Test Driver" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = Other
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
        , elapsed = elapsed
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


carNumbered : String -> List Lap -> Entrant
carNumbered carNumber laps =
    let
        base =
            carWithLaps laps

        metadata =
            base.metadata
    in
    { base | metadata = { metadata | carNumber = carNumber } }


{-| Every TookLead in the timeline, as (when, who).
-}
tookLeadEvents : List Entrant -> List ( Int, String )
tookLeadEvents entrants =
    TimelineEvent.fromEntrants entrants
        |> List.filterMap
            (\event ->
                case event.eventType of
                    CarEvent carNumber TookLead ->
                        Just ( event.eventTime, carNumber )

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
