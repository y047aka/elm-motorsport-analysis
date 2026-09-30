module Motorsport.Race.TimelineEvent exposing
    ( TimelineEvent, EventType(..), CarEventType(..)
    , fromJsonl, decoder
    , describe, forField, forCar
    , runningLap, handover
    )

{-| The race as a list of things that happened, in the order they happened.

Read out of the round's timeline file, which `Round.Timeline` writes.

@docs TimelineEvent, EventType, CarEventType
@docs fromJsonl, decoder
@docs describe, forField, forCar
@docs runningLap, handover

-}

import Internal.Jsonl as Jsonl
import Json.Decode as Decode exposing (Decoder, field, string)
import Motorsport.Driver exposing (Driver)
import Motorsport.Flag as Flag exposing (Flag)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)


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



-- WHAT IT IS CALLED, AND WHICH PANEL SHOWS IT


{-| What happened, in the words a timing sheet prints it in.

    describe RaceStart
    --> "Race Start"

    describe (CarEvent "51" FastestLap)
    --> "Fastest Lap"

-}
describe : EventType -> String
describe eventType =
    case eventType of
        RaceStart ->
            "Race Start"

        Flag flag ->
            Flag.toString flag

        CarEvent _ OvertakeForLead ->
            "Overtake for Lead"

        CarEvent _ LeaderInPit ->
            "Leader In Pit"

        CarEvent _ FastestLap ->
            "Fastest Lap"

        CarEvent _ DriverChange ->
            "Driver Change"

        CarEvent _ Retired ->
            "Retired"

        CarEvent _ Finished ->
            "Finished"


{-| Whether the field's panel draws the event.

    forField (CarEvent "51" FastestLap)
    --> True

    forField (CarEvent "51" DriverChange)
    --> False

-}
forField : EventType -> Bool
forField eventType =
    case eventType of
        CarEvent _ DriverChange ->
            False

        _ ->
            True


{-| Whether the event is one car's own, which is what that car's Log keeps.

A leader-in-pit event answers to no car: it is the field's leader crossing a
line, and the Log of the car it names already says when that car stopped.

    forCar "51" (CarEvent "51" FastestLap)
    --> True

    forCar "51" (CarEvent "83" FastestLap)
    --> False

    forCar "51" RaceStart
    --> False

-}
forCar : CarNumber -> EventType -> Bool
forCar carNumber eventType =
    case eventType of
        CarEvent _ LeaderInPit ->
            False

        CarEvent number _ ->
            number == carNumber

        _ ->
            False



-- THE LAP AN EVENT FELL ON


{-| The lap running when the event arrived: the last one the car had completed.

`Nothing` for an event before the car's first lap. Read off the car's laps whole
rather than the ones playback has reached, so a past event reads the same however
far the clock has run.

-}
runningLap : Car -> TimelineEvent -> Maybe Lap
runningLap car event =
    Lap.findLastLapAt { elapsed = event.elapsed } car.laps


{-| The two drivers a handover moved the car between, from the lap it came in on
and the one it went out on.

These are the two laps the feed gives a driver change to, and the pair says no
more than that: where the feed announces a change the laps do not show, the two
name the same driver.

-}
handover : Car -> TimelineEvent -> Maybe ( Driver, Driver )
handover car event =
    Maybe.map2 Tuple.pair
        (runningLap car event)
        (Lap.findCurrentLap { elapsed = event.elapsed } car.laps)
        |> Maybe.map (\( handedOver, tookOver ) -> ( handedOver.driver, tookOver.driver ))



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
