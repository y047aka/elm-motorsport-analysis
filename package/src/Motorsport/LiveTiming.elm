module Motorsport.LiveTiming exposing
    ( LiveTimingMessage(..), ConnectionStatus(..)
    , LiveUpdateData, CarUpdate
    , liveTimingMessageDecoder, liveUpdateDataDecoder, carUpdateDecoder
    , connectionStatusToString
    )

{-| Live Timing data types and decoders for real-time race data updates.

@docs LiveTimingMessage, ConnectionStatus
@docs LiveUpdateData, CarUpdate
@docs liveTimingMessageDecoder, liveUpdateDataDecoder, carUpdateDecoder
@docs connectionStatusToString

-}

import Json.Decode as Decode exposing (Decoder, field, int, string, list, maybe)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (optional, required)
import Motorsport.Car exposing (CarNumber)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.TimelineEvent as TimelineEvent exposing (TimelineEvent)
import Time


{-| Connection status for WebSocket
-}
type ConnectionStatus
    = Disconnected
    | Connecting
    | Connected
    | Reconnecting Int
    | Error String


{-| Messages from WebSocket
-}
type LiveTimingMessage
    = ConnectionStatusChanged ConnectionStatus
    | LiveUpdate LiveUpdateData
    | ParseError String


{-| Live update data containing incremental race information
-}
type alias LiveUpdateData =
    { timestamp : Time.Posix
    , raceTime : Duration
    , updatedCars : List CarUpdate
    , newEvents : List TimelineEvent
    }


{-| Incremental update for a single car
-}
type alias CarUpdate =
    { carNumber : CarNumber
    , position : Maybe Int
    , currentLap : Maybe Lap
    , lastCompletedLap : Maybe Lap
    , gap : Maybe String
    , interval : Maybe String
    , inPit : Maybe Bool
    }



-- DECODERS


{-| Decode LiveTimingMessage from WebSocket
-}
liveTimingMessageDecoder : Decoder LiveTimingMessage
liveTimingMessageDecoder =
    field "type" string
        |> Decode.andThen
            (\msgType ->
                case msgType of
                    "connected" ->
                        Decode.succeed (ConnectionStatusChanged Connected)

                    "disconnected" ->
                        Decode.map
                            (\reason ->
                                ConnectionStatusChanged
                                    (Error (Maybe.withDefault "Connection closed" reason))
                            )
                            (maybe (field "reason" string))

                    "error" ->
                        Decode.map
                            (\error ->
                                ConnectionStatusChanged
                                    (Error (Maybe.withDefault "Unknown error" error))
                            )
                            (maybe (field "error" string))

                    "data" ->
                        field "payload" liveUpdateDataDecoder
                            |> Decode.map LiveUpdate

                    _ ->
                        Decode.fail ("Unknown message type: " ++ msgType)
            )


{-| Decode LiveUpdateData
-}
liveUpdateDataDecoder : Decoder LiveUpdateData
liveUpdateDataDecoder =
    Decode.succeed LiveUpdateData
        |> required "timestamp" timestampDecoder
        |> required "raceTime" durationDecoder
        |> optional "updatedCars" (list carUpdateDecoder) []
        |> optional "newEvents" (list TimelineEvent.decoder) []


{-| Decode CarUpdate
-}
carUpdateDecoder : Decoder CarUpdate
carUpdateDecoder =
    Decode.succeed CarUpdate
        |> required "carNumber" string
        |> optional "position" (maybe int) Nothing
        |> optional "currentLap" (maybe lapDecoder) Nothing
        |> optional "lastCompletedLap" (maybe lapDecoder) Nothing
        |> optional "gap" (maybe string) Nothing
        |> optional "interval" (maybe string) Nothing
        |> optional "inPit" (maybe Decode.bool) Nothing



-- HELPER DECODERS


timestampDecoder : Decoder Time.Posix
timestampDecoder =
    int
        |> Decode.map Time.millisToPosix


durationDecoder : Decoder Duration
durationDecoder =
    TimelineEvent.durationDecoder


lapDecoder : Decoder Lap
lapDecoder =
    TimelineEvent.lapDecoder



-- UTILITIES


{-| Convert ConnectionStatus to a human-readable string
-}
connectionStatusToString : ConnectionStatus -> String
connectionStatusToString status =
    case status of
        Disconnected ->
            "Disconnected"

        Connecting ->
            "Connecting..."

        Connected ->
            "Connected"

        Reconnecting attempt ->
            "Reconnecting (attempt " ++ String.fromInt attempt ++ ")..."

        Error msg ->
            "Error: " ++ msg

