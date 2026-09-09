module Fixture.Json exposing (decode)

import Data.Wec as Wec
import Data.Wec.Laps as Laps
import Dict
import Json.Decode as Decode
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car
import Motorsport.Wec.Era as Era


{-| The fixture is the 2025 Fuji 6 Hours; see `benchmark/generate-fixture.mjs`.

A round is its entry list and the indices the summary spells out, so both are
read here and the race comes back built rather than as cars a caller would have
to assemble. `Race.empty` stands in for a fixture that did not decode, as it
does for a round that has not loaded.

-}
decode : { summary : String, laps : String } -> Race
decode raw =
    case ( Decode.decodeString (Wec.eventDecoder Era.Gt3AsThirdClass Dict.empty) raw.summary, Laps.fromJsonl raw.laps ) of
        ( Ok event, Ok rawLaps ) ->
            event.startingGrid.entries
                |> List.map Car.fromStartingGrid
                |> Laps.attach rawLaps
                |> Race.fromCars { timeLimit = event.timeLimit, index = event.index }

        _ ->
            Race.empty
