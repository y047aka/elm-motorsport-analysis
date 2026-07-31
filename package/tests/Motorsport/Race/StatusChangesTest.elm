module Motorsport.Race.StatusChangesTest exposing (suite)

import Expect
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.Race.StatusChanges as StatusChanges exposing (StatusChanges)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)
import Motorsport.Status as Status
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Race.StatusChanges"
        [ describe "statusAt"
            [ test "a car the index does not have has not taken the start" <|
                \_ ->
                    Expect.equal
                        ( Status.PreRace, Status.PreRace )
                        ( StatusChanges.statusAt { elapsed = 500000 } "99" index
                        , StatusChanges.statusAt { elapsed = 500000 } "1" StatusChanges.empty
                        )
            , test "a change takes effect on the instant it happens, not the one after" <|
                \_ ->
                    Expect.equal
                        ( Status.Racing, Status.InPit )
                        ( StatusChanges.statusAt { elapsed = 169999 } "1" index
                        , StatusChanges.statusAt { elapsed = 170000 } "1" index
                        )
            , test "taking the lead is not a status change" <|
                \_ ->
                    StatusChanges.statusAt { elapsed = 210000 } "1" index
                        |> Expect.equal Status.Racing
            , test "the last of two changes sharing an instant wins" <|
                \_ ->
                    let
                        pitOutThenFlag =
                            StatusChanges.fromTimelineEvents
                                [ carEvent 300000 (TimelineEvent.PitOut { lapNumber = 9, duration = 25000 })
                                , carEvent 300000 TimelineEvent.Checkered
                                ]
                    in
                    StatusChanges.statusAt { elapsed = 300000 } "1" pitOutThenFlag
                        |> Expect.equal Status.Checkered
            ]
        , describe "fromTimelineEvents"
            [ test "events are kept apart by car number" <|
                \_ ->
                    let
                        twoCars =
                            StatusChanges.fromTimelineEvents
                                [ { eventTime = 0, eventType = TimelineEvent.CarEvent "1" (TimelineEvent.Start { currentLap = Lap.empty }) }
                                , { eventTime = 0, eventType = TimelineEvent.CarEvent "2" (TimelineEvent.Start { currentLap = Lap.empty }) }
                                , { eventTime = 100000, eventType = TimelineEvent.CarEvent "2" TimelineEvent.Retirement }
                                ]
                    in
                    Expect.equal
                        ( Status.Racing, Status.Retired )
                        ( StatusChanges.statusAt { elapsed = 200000 } "1" twoCars
                        , StatusChanges.statusAt { elapsed = 200000 } "2" twoCars
                        )
            ]
        ]



-- FIXTURE


{-| One car's race: away at the start, two pit stops, and the flag at 15 minutes.
The lead it takes in the middle is there to be ignored.
-}
index : StatusChanges
index =
    StatusChanges.fromTimelineEvents
        [ carEvent 0 (TimelineEvent.Start { currentLap = Lap.empty })
        , carEvent 170000 (TimelineEvent.PitIn { lapNumber = 2, duration = 30000 })
        , carEvent 200000 (TimelineEvent.PitOut { lapNumber = 2, duration = 30000 })
        , carEvent 210000 TimelineEvent.TookLead
        , carEvent 400000 (TimelineEvent.PitIn { lapNumber = 5, duration = 25000 })
        , carEvent 425000 (TimelineEvent.PitOut { lapNumber = 5, duration = 25000 })
        , carEvent 900000 TimelineEvent.Checkered
        ]



-- HELPERS


carEvent : Duration -> TimelineEvent.CarEventType -> TimelineEvent
carEvent eventTime carEventType =
    { eventTime = eventTime, eventType = TimelineEvent.CarEvent "1" carEventType }
