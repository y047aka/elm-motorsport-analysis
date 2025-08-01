module Motorsport.TimelineEvent exposing
    ( TimelineEvent, EventType(..), CarEventType(..)
    , decoder, eventTimeDecoder, eventTypeDecoder, carEventTypeDecoder
    )

{-|

@docs TimelineEvent, EventType, CarEventType
@docs decoder, eventTimeDecoder, eventTypeDecoder, carEventTypeDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, int, string)
import Motorsport.Car exposing (CarNumber)
import Motorsport.Duration as Duration exposing (Duration)


type alias TimelineEvent =
    { eventTime : Duration, eventType : EventType }


type EventType
    = RaceStart
    | CarEvent CarNumber CarEventType


type CarEventType
    = Retirement
    | Checkered
    | LapCompleted Int


decoder : Decoder TimelineEvent
decoder =
    Decode.map2 TimelineEvent
        (field "event_time" eventTimeDecoder)
        (field "event_type" eventTypeDecoder)


eventTimeDecoder : Decoder Duration
eventTimeDecoder =
    string
        |> Decode.andThen
            (\str ->
                case Duration.fromString str of
                    Just duration ->
                        Decode.succeed duration

                    Nothing ->
                        Decode.fail ("Invalid duration format: " ++ str)
            )


eventTypeDecoder : Decoder EventType
eventTypeDecoder =
    Decode.oneOf
        [ Decode.map (\_ -> RaceStart)
            (Decode.string
                |> Decode.andThen
                    (\s ->
                        if s == "RaceStart" then
                            Decode.succeed ()

                        else
                            Decode.fail "Expected RaceStart"
                    )
            )
        , Decode.map2 CarEvent
            (field "CarEvent" (Decode.index 0 string))
            (field "CarEvent" (Decode.index 1 carEventTypeDecoder))
        ]


carEventTypeDecoder : Decoder CarEventType
carEventTypeDecoder =
    Decode.oneOf
        [ Decode.map (\_ -> Retirement)
            (Decode.string
                |> Decode.andThen
                    (\s ->
                        if s == "Retirement" then
                            Decode.succeed ()

                        else
                            Decode.fail "Expected Retirement"
                    )
            )
        , Decode.map (\_ -> Checkered)
            (Decode.string
                |> Decode.andThen
                    (\s ->
                        if s == "Checkered" then
                            Decode.succeed ()

                        else
                            Decode.fail "Expected Checkered"
                    )
            )
        , Decode.map LapCompleted
            (field "LapCompleted" int)
        ]
