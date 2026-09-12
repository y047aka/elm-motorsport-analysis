module Motorsport.Race.TimelineTest exposing (suite)

import Expect
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Race.Timeline"
        [ describe "countUpTo"
            [ test "nothing has happened in an empty timeline" <|
                \_ ->
                    Timeline.countUpTo (Instant.fromDuration 500000) Timeline.empty
                        |> Expect.equal 0
            , test "an event counts on the instant it happens, not the one after" <|
                \_ ->
                    ( Timeline.countUpTo (Instant.fromDuration 169999) timeline
                    , Timeline.countUpTo (Instant.fromDuration 170000) timeline
                    )
                        |> Expect.equal ( 1, 2 )
            , test "events sharing an instant are counted together" <|
                \_ ->
                    ( Timeline.countUpTo (Instant.fromDuration 399999) timeline
                    , Timeline.countUpTo (Instant.fromDuration 400000) timeline
                    )
                        |> Expect.equal ( 4, 6 )
            , test "a clock past the last event has reached all of them" <|
                \_ ->
                    Timeline.countUpTo (Instant.fromDuration 9999999) timeline
                        |> Expect.equal 6
            , test "a clock before the first has reached none" <|
                \_ ->
                    Timeline.countUpTo Instant.raceStart timeline
                        |> Expect.equal 0
            , test "a timeline read out of time order is counted in it" <|
                \_ ->
                    Timeline.countUpTo (Instant.fromDuration 250000) reversed
                        |> Expect.equal 3
            ]
        , describe "latest"
            [ test "newest first, the last of the ones that have happened" <|
                \_ ->
                    Timeline.latest { upTo = 4, limit = 2 } timeline
                        |> List.map elapsedOf
                        |> Expect.equal [ 300000, 200000 ]
            , test "fewer than the limit have happened" <|
                \_ ->
                    Timeline.latest { upTo = 2, limit = 100 } timeline
                        |> List.map elapsedOf
                        |> Expect.equal [ 170000, 1000 ]
            , test "a count of none is no rows" <|
                \_ ->
                    Timeline.latest { upTo = 0, limit = 100 } timeline
                        |> Expect.equal []
            , test "a count past the end takes the timeline it has" <|
                \_ ->
                    Timeline.latest { upTo = 99, limit = 2 } timeline
                        |> List.map elapsedOf
                        |> Expect.equal [ 400000, 400000 ]
            , test "a timeline read out of time order still gives its rows newest first" <|
                \_ ->
                    Timeline.latest { upTo = 3, limit = 2 } reversed
                        |> List.map elapsedOf
                        |> Expect.equal [ 200000, 170000 ]
            ]
        ]


timeline : Timeline
timeline =
    Timeline.fromList events


reversed : Timeline
reversed =
    Timeline.fromList (List.reverse events)


events : List TimelineEvent
events =
    [ eventAt 1000 TimelineEvent.RaceStart
    , eventAt 170000 (TimelineEvent.CarEvent "1" (TimelineEvent.PitIn { lapNumber = 2, duration = 30000 }))
    , eventAt 200000 (TimelineEvent.CarEvent "1" (TimelineEvent.PitOut { lapNumber = 2, duration = 30000 }))
    , eventAt 300000 (TimelineEvent.CarEvent "2" TimelineEvent.TookLead)
    , eventAt 400000 (TimelineEvent.CarEvent "1" TimelineEvent.Retirement)
    , eventAt 400000 (TimelineEvent.CarEvent "2" TimelineEvent.Checkered)
    ]


eventAt : Duration -> TimelineEvent.EventType -> TimelineEvent
eventAt elapsed eventType =
    { elapsed = Instant.fromDuration elapsed, eventType = eventType }


elapsedOf : TimelineEvent -> Duration
elapsedOf event =
    Instant.toDuration event.elapsed
