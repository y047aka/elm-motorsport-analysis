module Motorsport.Race.StatusIndexTest exposing (suite)

import Expect
import Motorsport.Car as Car
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.Race.StatusIndex as StatusIndex exposing (StatusIndex)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Race.StatusIndex"
        [ describe "statusAt"
            [ test "a car the race never mentions has not taken the start" <|
                \_ ->
                    StatusIndex.statusAt { elapsed = 500000 } "99" index
                        |> Expect.equal Car.PreRace
            , test "an empty index leaves every car pre-race" <|
                \_ ->
                    StatusIndex.statusAt { elapsed = 500000 } "1" StatusIndex.empty
                        |> Expect.equal Car.PreRace
            , test "a change takes effect on the instant it happens, not the one after" <|
                \_ ->
                    Expect.equal
                        ( Car.Racing, Car.InPit )
                        ( StatusIndex.statusAt { elapsed = 169999 } "1" index
                        , StatusIndex.statusAt { elapsed = 170000 } "1" index
                        )
            , test "taking the lead is not a status change" <|
                \_ ->
                    StatusIndex.statusAt { elapsed = 210000 } "1" index
                        |> Expect.equal Car.Racing
            , test "the last of two changes sharing an instant wins" <|
                \_ ->
                    let
                        pitOutThenFlag =
                            StatusIndex.fromTimelineEvents
                                [ carEvent 300000 (TimelineEvent.PitOut { lapNumber = 9, duration = 25000 })
                                , carEvent 300000 TimelineEvent.Checkered
                                ]
                    in
                    StatusIndex.statusAt { elapsed = 300000 } "1" pitOutThenFlag
                        |> Expect.equal Car.Checkered
            ]
        , describe "fromTimelineEvents"
            [ test "events are kept apart by car number" <|
                \_ ->
                    let
                        twoCars =
                            StatusIndex.fromTimelineEvents
                                [ { eventTime = 0, eventType = TimelineEvent.CarEvent "1" (TimelineEvent.Start { currentLap = Lap.empty }) }
                                , { eventTime = 0, eventType = TimelineEvent.CarEvent "2" (TimelineEvent.Start { currentLap = Lap.empty }) }
                                , { eventTime = 100000, eventType = TimelineEvent.CarEvent "2" TimelineEvent.Retirement }
                                ]
                    in
                    Expect.equal
                        ( Car.Racing, Car.Retired )
                        ( StatusIndex.statusAt { elapsed = 200000 } "1" twoCars
                        , StatusIndex.statusAt { elapsed = 200000 } "2" twoCars
                        )
            ]
        ]



-- FIXTURE


{-| One car's race: away at the start, two pit stops, and the flag at 15 minutes.
The lead it takes in the middle is there to be ignored.
-}
changes : List ( Duration, TimelineEvent.CarEventType )
changes =
    [ ( 0, TimelineEvent.Start { currentLap = Lap.empty } )
    , ( 170000, TimelineEvent.PitIn { lapNumber = 2, duration = 30000 } )
    , ( 200000, TimelineEvent.PitOut { lapNumber = 2, duration = 30000 } )
    , ( 210000, TimelineEvent.TookLead )
    , ( 400000, TimelineEvent.PitIn { lapNumber = 5, duration = 25000 } )
    , ( 425000, TimelineEvent.PitOut { lapNumber = 5, duration = 25000 } )
    , ( 900000, TimelineEvent.Checkered )
    ]


index : StatusIndex
index =
    StatusIndex.fromTimelineEvents (List.map (\( at, carEventType ) -> carEvent at carEventType) changes)



-- HELPERS


carEvent : Duration -> TimelineEvent.CarEventType -> TimelineEvent
carEvent eventTime carEventType =
    { eventTime = eventTime, eventType = TimelineEvent.CarEvent "1" carEventType }
