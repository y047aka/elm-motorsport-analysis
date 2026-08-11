module Fixture.Json exposing (decode)

import Data.Wec as Wec
import Data.Wec.Laps as Laps
import Json.Decode as Decode
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Wec.Era as Era


{-| The fixture is the 2025 Fuji 6 Hours; see `benchmark/generate-fixture.mjs`.
-}
decode : { summary : String, laps : String } -> List Car
decode raw =
    case ( Decode.decodeString (Wec.eventDecoder Era.Gt3AsThirdClass) raw.summary, Laps.fromJsonl raw.laps ) of
        ( Ok event, Ok rawLaps ) ->
            event.startingGrid.entries
                |> List.map Car.fromStartingGrid
                |> Laps.attach rawLaps

        _ ->
            []
