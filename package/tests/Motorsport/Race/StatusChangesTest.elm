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
                        ( Status.Racing, Status.InPit )
                        ( StatusChanges.statusAt { elapsed = Instant.fromDuration 169999 } "1" index
                        , StatusChanges.statusAt { elapsed = Instant.fromDuration 170000 } "1" index
                        )
            , test "taking the lead is not a status change" <|
                \_ ->
                    StatusChanges.statusAt { elapsed = Instant.fromDuration 210000 } "1" index
                        |> Expect.equal Status.Racing
            , test "the stronger of two changes sharing an instant wins" <|
                \_ ->
                    let
                        pitOutAndFlag =
                            StatusChanges.fromTimelineEvents
                                [ carEvent 300000 (TimelineEvent.PitOut { lapNumber = 9, duration = 25000 })
                                , carEvent 300000 TimelineEvent.Checkered
                                ]
                    in
                    StatusChanges.statusAt { elapsed = Instant.fromDuration 300000 } "1" pitOutAndFlag
                        |> Expect.equal Status.Checkered
            , test "and wins from either side of the list" <|
                \_ ->
                    let
                        statusAtTheFlag events =
                            StatusChanges.statusAt
                                { elapsed = Instant.fromDuration 300000 }
                                "1"
                                (StatusChanges.fromTimelineEvents events)

                        pitOut =
                            carEvent 300000 (TimelineEvent.PitOut { lapNumber = 9, duration = 25000 })
                    in
                    Expect.equal
                        ( Status.Checkered, Status.Retired )
                        ( statusAtTheFlag [ carEvent 300000 TimelineEvent.Checkered, pitOut ]
                        , statusAtTheFlag [ carEvent 300000 TimelineEvent.Retirement, pitOut ]
                        )
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
            , test "the same events shuffled build the same index" <|
                \_ ->
                    let
                        events =
                            [ carEvent 0 TimelineEvent.Start
                            , carEvent 170000 (TimelineEvent.PitIn { lapNumber = 2, duration = 30000 })
                            , carEvent 200000 (TimelineEvent.PitOut { lapNumber = 2, duration = 30000 })
                            , carEvent 200000 TimelineEvent.Retirement
                            ]

                        readings from =
                            let
                                built =
                                    StatusChanges.fromTimelineEvents from
                            in
                            [ 0, 169999, 170000, 200000, 900000 ]
                                |> List.map
                                    (\at ->
                                        StatusChanges.statusAt
                                            { elapsed = Instant.fromDuration at }
                                            "1"
                                            built
                                    )
                    in
                    Expect.equal (readings events) (readings (List.reverse events))
            ]
        ]



-- FIXTURE


{-| One car's race: away at the start, two pit stops, and the flag at 15 minutes.
The lead it takes in the middle is there to be ignored.
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
