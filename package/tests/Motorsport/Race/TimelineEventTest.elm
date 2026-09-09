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
                decoded """{ "elapsed": "0.000", "event": "start", "carNumber": "7" }"""
                    |> Expect.equal (Ok ( Instant.raceStart, CarEvent "7" Start ))
        , test "a stop carries the lap it ended on and how long it took" <|
            \_ ->
                decoded """{ "elapsed": "1:50.000", "event": "pitIn", "carNumber": "7", "lap": 2, "duration": "1:10.000" }"""
                    |> Expect.equal
                        (Ok
                            ( Instant.fromDuration 110000
                            , CarEvent "7" (PitIn { lapNumber = 2, duration = 70000 })
                            )
                        )
        , test "and its other half says the same of itself" <|
            \_ ->
                decoded """{ "elapsed": "3:00.000", "event": "pitOut", "carNumber": "7", "lap": 2, "duration": "1:10.000" }"""
                    |> Expect.equal
                        (Ok
                            ( Instant.fromDuration 180000
                            , CarEvent "7" (PitOut { lapNumber = 2, duration = 70000 })
                            )
                        )
        , test "each of the remaining kinds reads back as itself" <|
            \_ ->
                [ "tookLead", "retirement", "checkered" ]
                    |> List.map
                        (\event ->
                            decoded ("{ \"elapsed\": \"0.000\", \"event\": \"" ++ event ++ "\", \"carNumber\": \"7\" }")
                                |> Result.map Tuple.second
                        )
                    |> Expect.equal
                        [ Ok (CarEvent "7" TookLead)
                        , Ok (CarEvent "7" Retirement)
                        , Ok (CarEvent "7" Checkered)
                        ]
        , test "a kind this app has no case for fails the round" <|
            \_ ->
                -- Carried on from, it would read as a car that never stopped.
                decoded """{ "elapsed": "0.000", "event": "safetyCar" }"""
                    |> Expect.err
        ]


{-| `(when, what)`, which is the whole of an event.
-}
decoded : String -> Result Decode.Error ( Instant, EventType )
decoded json =
    Decode.decodeString TimelineEvent.decoder json
        |> Result.map (\event -> ( event.elapsed, event.eventType ))
