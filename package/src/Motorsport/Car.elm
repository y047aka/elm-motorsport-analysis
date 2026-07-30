module Motorsport.Car exposing
    ( Car, at
    , Status(..), hasRetired, statusToString
    )

{-| An entrant as it stands at one moment of the race.

The entry-list fields come straight from
[`Entrant`](Motorsport-Race-Entrant#Entrant); everything after them is read off the
clock -- the lap in progress, the lap just finished, who is driving, what the
car's status is.

None of it is stored between frames. `at` rebuilds the car from an entrant and an
elapsed time, so the same elapsed always gives the same car, however the clock
got there.

@docs Car, at
@docs Status, hasRetired, statusToString

-}

import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Entrant as Entrant exposing (Entrant)


type alias Car =
    { metadata : Entrant.Metadata
    , startPosition : Int
    , laps : List Lap
    , currentLap : Maybe Lap
    , lastLap : Maybe Lap
    , status : Status
    , currentDriver : Maybe Driver
    }


{-| Read an entrant at a moment of the race.

The status is handed in rather than worked out here: it comes from the race's
precomputed change points, see
[`Race.StatusIndex.statusAt`](Motorsport-Race-StatusIndex#statusAt).

-}
at : { elapsed : Duration, status : Status } -> Entrant -> Car
at { elapsed, status } entrant =
    let
        clock =
            { elapsed = elapsed }

        currentLap =
            Lap.findCurrentLap clock entrant.laps
    in
    { metadata = entrant.metadata
    , startPosition = entrant.startPosition
    , laps = entrant.laps
    , currentLap = currentLap
    , lastLap = Lap.findLastLapAt clock entrant.laps
    , status = status
    , currentDriver = Maybe.map .driver currentLap
    }



-- STATUS


type Status
    = PreRace
    | Racing
    | InPit
    | Checkered
    | Retired


hasRetired : Status -> Bool
hasRetired =
    (==) Retired


statusToString : Status -> String
statusToString status =
    case status of
        PreRace ->
            "Pre-Race"

        Racing ->
            "Racing"

        InPit ->
            "In Pit"

        Checkered ->
            "Checkered"

        Retired ->
            "Retired"
