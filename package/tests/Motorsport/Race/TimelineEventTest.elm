module Motorsport.Race.TimelineEventTest exposing (suite)

import Expect
import Json.Decode as Decode
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..), RaceFlag(..))
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
                decoded """{ "elapsed": "0.000", "event": "overtakeForLead", "carNumber": "7" }"""
                    |> Expect.equal (Ok ( Instant.raceStart, CarEvent "7" OvertakeForLead ))
        , test "each of the kinds reads back as itself" <|
            \_ ->
                [ "overtakeForLead", "leaderInPit", "fastestLap", "driverChange", "retired", "finished" ]
                    |> List.map (written >> Result.map Tuple.second)
                    |> Expect.equal
                        [ Ok (CarEvent "7" OvertakeForLead)
                        , Ok (CarEvent "7" LeaderInPit)
                        , Ok (CarEvent "7" FastestLap)
                        , Ok (CarEvent "7" DriverChange)
                        , Ok (CarEvent "7" Retired)
                        , Ok (CarEvent "7" Finished)
                        ]
        , test "a flag is nobody's, and reads back as itself" <|
            \_ ->
                [ "fullCourseYellow", "safetyCar", "redFlag", "greenFlag" ]
                    |> List.map (\name -> decoded ("{ \"elapsed\": \"1:00.000\", \"event\": \"" ++ name ++ "\" }") |> Result.map Tuple.second)
                    |> Expect.equal
                        [ Ok (Flag FullCourseYellow)
                        , Ok (Flag SafetyCar)
                        , Ok (Flag RedFlag)
                        , Ok (Flag GreenFlag)
                        ]
        , test "a kind this app has no case for fails the round" <|
            \_ ->
                -- Carried on from, a car's event of a kind this app cannot read
                -- would read as a car that never stopped running.
                decoded """{ "elapsed": "0.000", "event": "slowZone" }"""
                    |> Expect.err
        , test "a name this timeline no longer writes fails the round" <|
            \_ ->
                [ "start", "tookLead", "retirement", "checkered" ]
                    |> List.map (written >> Result.toMaybe)
                    |> Expect.equal [ Nothing, Nothing, Nothing, Nothing ]
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
