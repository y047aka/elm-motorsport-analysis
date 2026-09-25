module Motorsport.Race.TimelineEvent exposing
    ( TimelineEvent, EventType(..), CarEventType(..)
    , fromJsonl, decoder
    )

{-| The race as a list of things that happened, in the order they happened.

Read out of the round's timeline file, which `Round.Timeline` writes.

@docs TimelineEvent, EventType, CarEventType
@docs fromJsonl, decoder

-}

import Internal.Jsonl as Jsonl
import Json.Decode as Decode exposing (Decoder, field, string)
import Motorsport.Flag as Flag exposing (Flag)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.Car exposing (CarNumber)


type alias TimelineEvent =
    { elapsed : Instant, eventType : EventType }


type EventType
    = RaceStart
    | Flag Flag
    | CarEvent CarNumber CarEventType


type CarEventType
    = OvertakeForLead
    | LeaderInPit
    | FastestLap
    | DriverChange
    | Retired
    | Finished



-- DECODE


{-| Reads the timeline file, which holds one event per line rather than one
array.
-}
fromJsonl : String -> Result String (List TimelineEvent)
fromJsonl =
    Jsonl.decode decoder


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
    case ( event, Flag.fromString event ) of
        ( "raceStart", _ ) ->
            Decode.succeed RaceStart

        ( _, Just flag ) ->
            Decode.succeed (Flag flag)

        ( _, Nothing ) ->
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
        "overtakeForLead" ->
            Decode.succeed OvertakeForLead

        "leaderInPit" ->
            Decode.succeed LeaderInPit

        "fastestLap" ->
            Decode.succeed FastestLap

        "driverChange" ->
            Decode.succeed DriverChange

        "retired" ->
            Decode.succeed Retired

        "finished" ->
            Decode.succeed Finished

        _ ->
            Decode.fail ("Unknown timeline event: " ++ event)
