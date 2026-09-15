module Motorsport.Race.StatusChangesTest exposing (suite)

import Expect
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
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
                        ( StatusChanges.statusAt { elapsed = Instant.fromDuration 500000 } "99" index
                        , StatusChanges.statusAt { elapsed = Instant.fromDuration 500000 } "1" StatusChanges.empty
                        )
            , test "a change takes effect on the instant it happens, not the one after" <|
                \_ ->
                    Expect.equal
                        ( Status.Racing, Status.Checkered )
                        ( StatusChanges.statusAt { elapsed = Instant.fromDuration 899999 } "1" index
                        , StatusChanges.statusAt { elapsed = Instant.fromDuration 900000 } "1" index
                        )
            , test "the pit lane is not in this index" <|
                \_ ->
                    -- Both halves of both stops, and the moments between them.
                    [ 170000, 185000, 200000, 400000, 412000, 425000 ]
                        |> List.map (\at -> StatusChanges.statusAt { elapsed = Instant.fromDuration at } "1" index)
                        |> Expect.equal (List.repeat 6 Status.Racing)
            , test "taking the lead is not a status change" <|
                \_ ->
                    StatusChanges.statusAt { elapsed = Instant.fromDuration 210000 } "1" index
                        |> Expect.equal Status.Racing
            , test "the last of two changes sharing an instant wins" <|
                \_ ->
                    let
                        retiredThenFlag =
                            StatusChanges.fromTimelineEvents
                                [ carEvent 300000 TimelineEvent.Retirement
                                , carEvent 300000 TimelineEvent.Checkered
                                ]
                    in
                    StatusChanges.statusAt { elapsed = Instant.fromDuration 300000 } "1" retiredThenFlag
                        |> Expect.equal Status.Checkered
            ]
        , describe "fromTimelineEvents"
            [ test "events are kept apart by car number" <|
                \_ ->
                    let
                        twoCars =
                            StatusChanges.fromTimelineEvents
                                [ { elapsed = Instant.raceStart, eventType = TimelineEvent.CarEvent "1" TimelineEvent.Start }
                                , { elapsed = Instant.raceStart, eventType = TimelineEvent.CarEvent "2" TimelineEvent.Start }
                                , { elapsed = Instant.fromDuration 100000, eventType = TimelineEvent.CarEvent "2" TimelineEvent.Retirement }
                                ]
                    in
                    Expect.equal
                        ( Status.Racing, Status.Retired )
                        ( StatusChanges.statusAt { elapsed = Instant.fromDuration 200000 } "1" twoCars
                        , StatusChanges.statusAt { elapsed = Instant.fromDuration 200000 } "2" twoCars
                        )
            ]
        ]



-- FIXTURE


{-| One car's race: away at the start, two pit stops, and the flag at 15 minutes.
The stops and the lead it takes between them are there to be ignored.
-}
index : StatusChanges
index =
    StatusChanges.fromTimelineEvents
        [ carEvent 0 TimelineEvent.Start
        , carEvent 170000 (TimelineEvent.PitIn { lapNumber = 2, duration = 30000 })
        , carEvent 200000 (TimelineEvent.PitOut { lapNumber = 2, duration = 30000 })
        , carEvent 210000 TimelineEvent.TookLead
        , carEvent 400000 (TimelineEvent.PitIn { lapNumber = 5, duration = 25000 })
        , carEvent 425000 (TimelineEvent.PitOut { lapNumber = 5, duration = 25000 })
        , carEvent 900000 TimelineEvent.Checkered
        ]



-- HELPERS


carEvent : Duration -> TimelineEvent.CarEventType -> TimelineEvent
carEvent elapsed carEventType =
    { elapsed = Instant.fromDuration elapsed
    , eventType = TimelineEvent.CarEvent "1" carEventType
    }
