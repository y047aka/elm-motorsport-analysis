module Motorsport.Car.StatusIndexTest exposing (suite)

import Expect
import Motorsport.Car as Car
import Motorsport.Car.StatusIndex as StatusIndex exposing (StatusIndex)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.TimelineEvent as TimelineEvent exposing (TimelineEvent)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Car.StatusIndex"
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
            , test "a lap completion is not a status change" <|
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
            , test "the search agrees with a linear scan at every sampled instant" <|
                \_ ->
                    let
                        samples =
                            [ -1, 0, 1, 169999, 170000, 170001, 199999, 200000, 200001, 210000, 399999, 400000, 424999, 425000, 899999, 900000, 900001, 5000000 ]
                    in
                    samples
                        |> List.map (\elapsed -> StatusIndex.statusAt { elapsed = elapsed } "1" index)
                        |> Expect.equal (List.map linearScan samples)
            , test "the search agrees with a linear scan over a long stint list too" <|
                \_ ->
                    let
                        manyChanges =
                            List.range 1 200
                                |> List.map
                                    (\i ->
                                        if modBy 2 i == 0 then
                                            ( i * 1000, TimelineEvent.PitOut { lapNumber = i, duration = 0 } )

                                        else
                                            ( i * 1000, TimelineEvent.PitIn { lapNumber = i, duration = 0 } )
                                    )

                        longIndex =
                            StatusIndex.fromTimelineEvents (List.map (\( at, carEventType ) -> carEvent at carEventType) manyChanges)

                        samples =
                            List.range 0 402 |> List.map (\i -> i * 500)
                    in
                    samples
                        |> List.map (\elapsed -> StatusIndex.statusAt { elapsed = elapsed } "1" longIndex)
                        |> Expect.equal (List.map (scanOver manyChanges) samples)
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
The lap completion in the middle is there to be ignored.
-}
changes : List ( Duration, TimelineEvent.CarEventType )
changes =
    [ ( 0, TimelineEvent.Start { currentLap = Lap.empty } )
    , ( 170000, TimelineEvent.PitIn { lapNumber = 2, duration = 30000 } )
    , ( 200000, TimelineEvent.PitOut { lapNumber = 2, duration = 30000 } )
    , ( 210000, TimelineEvent.LapCompleted 2 { nextLap = Lap.empty } )
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


linearScan : Duration -> Car.Status
linearScan =
    scanOver changes


{-| The specification the index is meant to implement: walk the changes in order
and keep the last one at or before the clock.
-}
scanOver : List ( Duration, TimelineEvent.CarEventType ) -> Duration -> Car.Status
scanOver changes_ elapsed =
    changes_
        |> List.filter (\( at, _ ) -> at <= elapsed)
        |> List.filterMap (Tuple.second >> statusOf)
        |> List.reverse
        |> List.head
        |> Maybe.withDefault Car.PreRace


statusOf : TimelineEvent.CarEventType -> Maybe Car.Status
statusOf carEventType =
    case carEventType of
        TimelineEvent.Start _ ->
            Just Car.Racing

        TimelineEvent.PitIn _ ->
            Just Car.InPit

        TimelineEvent.PitOut _ ->
            Just Car.Racing

        TimelineEvent.Retirement ->
            Just Car.Retired

        TimelineEvent.Checkered ->
            Just Car.Checkered

        TimelineEvent.LapCompleted _ _ ->
            Nothing
