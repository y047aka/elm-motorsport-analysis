module Motorsport.Race.TimelineEventTest exposing (suite)

import Expect
import Json.Decode as Decode
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "TimelineEvent.decoder"
        [ test "the race's own start is nobody's" <|
            \_ ->
                decoded """{ "elapsed": "0.000", "event": "raceStart" }"""
                    |> Expect.equal (Ok ( Instant.raceStart, RaceStart ))
        , test "every other event names the car it was" <|
            \_ ->
                decoded """{ "elapsed": "0.000", "event": "tookLeadOnTrack", "carNumber": "7" }"""
                    |> Expect.equal (Ok ( Instant.raceStart, CarEvent "7" TookLeadOnTrack ))
        , test "each of the kinds reads back as itself" <|
            \_ ->
                [ "tookLeadOnTrack", "leaderPitted", "retirement", "checkered" ]
                    |> List.map (written >> Result.map Tuple.second)
                    |> Expect.equal
                        [ Ok (CarEvent "7" TookLeadOnTrack)
                        , Ok (CarEvent "7" LeaderPitted)
                        , Ok (CarEvent "7" Retirement)
                        , Ok (CarEvent "7" Checkered)
                        ]
        , test "a kind this app has no case for fails the round" <|
            \_ ->
                -- A caution episode would read as a car that never stopped running.
                decoded """{ "elapsed": "0.000", "event": "safetyCar" }"""
                    |> Expect.err
        , test "a name this timeline no longer writes fails the round" <|
            \_ ->
                [ "start", "tookLead" ]
                    |> List.map (written >> Result.toMaybe)
                    |> Expect.equal [ Nothing, Nothing ]
        ]


{-| An event of one name, of car 7, at nought.
-}
written : String -> Result Decode.Error ( Instant, EventType )
written name =
    decoded ("{ \"elapsed\": \"0.000\", \"event\": \"" ++ name ++ "\", \"carNumber\": \"7\" }")



{-| `(when, what)`, which is the whole of an event.
-}
decoded : String -> Result Decode.Error ( Instant, EventType )
decoded json =
    Decode.decodeString TimelineEvent.decoder json
        |> Result.map (\event -> ( event.elapsed, event.eventType ))
