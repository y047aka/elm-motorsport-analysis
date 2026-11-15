module Motorsport.Race.TimelineEvent exposing
    ( TimelineEvent, EventType(..), CarEventType(..)
    , Rated, LapDetail
    , fromJsonl, decoder
    , describe, forCar
    , runningLap, handover
    )

{-| The race as a list of things that happened, in the order they happened.

Read out of the round's timeline file, which `Round.Timeline` writes.

@docs TimelineEvent, EventType, CarEventType
@docs Rated, LapDetail
@docs fromJsonl, decoder
@docs describe, forCar
@docs runningLap, handover

-}

import Internal.Jsonl as Jsonl
import Json.Decode as Decode exposing (Decoder, field, string)
import Json.Decode.Pipeline exposing (required)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Flag as Flag exposing (Flag)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans exposing (ByMiniSector)


type alias TimelineEvent =
    { elapsed : Instant
    , eventType : EventType
    , lap : Maybe LapDetail
    }


type alias Rated =
    { time : Maybe Duration
    , fastest : Maybe Duration
    , personalBest : Maybe Duration
    }


{-| `miniSectors` is `Nothing` for a circuit the tracker has no lines for, which is a
lap drawn on the three sectors.

-}
type alias LapDetail =
    { number : Int
    , driver : String
    , lap : Rated
    , sectors : BySector Rated
    , miniSectors : Maybe (ByMiniSector Rated)
    }


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


{-| The handover the event marks: who brought the car in, and who took it on.

Read off the laps either side of the event -- the last one completed, and the one
running -- since that is where a timing feed stamps a driver change: as the car
goes back out.

-}
handover : Car -> TimelineEvent -> Maybe ( Driver, Driver )
handover car event =
    case
        ( Lap.findLastLapAt { elapsed = event.elapsed } car.laps
        , Lap.findCurrentLap { elapsed = event.elapsed } car.laps
        )
    of
        ( Just handedOver, Just tookOver ) ->
            Driver.changeBetween handedOver.driver tookOver.driver

        _ ->
            Nothing



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
    Decode.map3 TimelineEvent
        (field "elapsed" Instant.decoder)
        (field "event" string |> Decode.andThen eventTypeDecoder)
        -- The number is what the detail is read from, so a `lap` naming one with no
        -- `performance` beside it is a bad line rather than a plain event.
        (Decode.maybe (field "lap" Decode.int)
            |> Decode.andThen
                (\number ->
                    case number of
                        Nothing ->
                            Decode.succeed Nothing

                        Just _ ->
                            Decode.map Just lapDetailDecoder
                )
        )


{-| The lap an event fell on, which sits flat beside the event rather than under a key
of its own.

-}
lapDetailDecoder : Decoder LapDetail
lapDetailDecoder =
    Decode.map5 LapDetail
        (field "lap" Decode.int)
        (field "driver" Decode.string)
        (field "performance" (field "lap" ratedDecoder))
        (field "performance" (field "sectors" ratedBySectorDecoder))
        (Decode.maybe (field "performance" (field "miniSectors" ratedByMiniSectorDecoder)))


ratedDecoder : Decoder Rated
ratedDecoder =
    Decode.map3 Rated
        (field "time" Duration.optionalDecoder)
        (field "fastest" Duration.optionalDecoder)
        (field "personalBest" Duration.optionalDecoder)


ratedBySectorDecoder : Decoder (BySector Rated)
ratedBySectorDecoder =
    Decode.succeed BySector
        |> required "s1" ratedDecoder
        |> required "s2" ratedDecoder
        |> required "s3" ratedDecoder


{-| All fifteen, keyed by the name the file uses. A lap written without a time for one
of them has no segment there, which is a blank rather than a failure to read the lap.

-}
ratedByMiniSectorDecoder : Decoder (ByMiniSector Rated)
ratedByMiniSectorDecoder =
    Decode.succeed ByMiniSector
        |> required "scl2" ratedDecoder
        |> required "z4" ratedDecoder
        |> required "ip1" ratedDecoder
        |> required "z12" ratedDecoder
        |> required "sclc" ratedDecoder
        |> required "a7_1" ratedDecoder
        |> required "ip2" ratedDecoder
        |> required "a8_1" ratedDecoder
        |> required "sclb" ratedDecoder
        |> required "porin" ratedDecoder
        |> required "porout" ratedDecoder
        |> required "pitref" ratedDecoder
        |> required "scl1" ratedDecoder
        |> required "fordout" ratedDecoder
        |> required "fl" ratedDecoder


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
