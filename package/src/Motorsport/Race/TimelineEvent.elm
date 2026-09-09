module Motorsport.Race.TimelineEvent exposing
    ( TimelineEvent, EventType(..), CarEventType(..)
    , decoder
    )

{-| The race as a list of things that happened, in the order they happened.

Read out of the round's summary, which `Round.Timeline` writes.

@docs TimelineEvent, EventType, CarEventType
@docs decoder

-}

import Json.Decode as Decode exposing (Decoder, field, int, string)
import Json.Decode.Extra
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.Car exposing (CarNumber)


type alias TimelineEvent =
    { eventTime : Instant, eventType : EventType }


type EventType
    = RaceStart
    | CarEvent CarNumber CarEventType


type CarEventType
    = Start
    | TookLead
    | PitIn { lapNumber : Int, duration : Duration }
    | PitOut { lapNumber : Int, duration : Duration }
    | Retirement
    | Checkered



-- DECODE


{-| An event is one flat object: when it happened, what it was, and -- for all
but the race's own start -- whose it was.
-}
decoder : Decoder TimelineEvent
decoder =
    Decode.map2 TimelineEvent
        (field "elapsed" Instant.decoder)
        (field "event" string |> Decode.andThen eventTypeDecoder)


eventTypeDecoder : String -> Decoder EventType
eventTypeDecoder event =
    if event == "raceStart" then
        Decode.succeed RaceStart

    else
        Decode.map2 CarEvent
            (field "carNumber" string)
            (carEventTypeDecoder event)


{-| A name the CLI writes that this app has none of fails the round, as an
unreadable `sectors` does: the two disagree about the shape of the file, which
is not a thing to carry on from. An event silently dropped would read as a car
that never stopped.
-}
carEventTypeDecoder : String -> Decoder CarEventType
carEventTypeDecoder event =
    case event of
        "start" ->
            Decode.succeed Start

        "tookLead" ->
            Decode.succeed TookLead

        "pitIn" ->
            Decode.map PitIn stopDecoder

        "pitOut" ->
            Decode.map PitOut stopDecoder

        "retirement" ->
            Decode.succeed Retirement

        "checkered" ->
            Decode.succeed Checkered

        _ ->
            Decode.fail ("Unknown timeline event: " ++ event)


stopDecoder : Decoder { lapNumber : Int, duration : Duration }
stopDecoder =
    Decode.map2 (\lapNumber duration -> { lapNumber = lapNumber, duration = duration })
        (field "lap" int)
        (field "duration" durationDecoder)


durationDecoder : Decoder Duration
durationDecoder =
    string |> Decode.andThen (Duration.fromString >> Json.Decode.Extra.fromMaybe "Expected a Duration")
