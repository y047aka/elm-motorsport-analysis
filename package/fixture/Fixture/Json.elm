module Fixture.Json exposing (decode, event, miniSectorNames)

{-| The way the app reads a round, applied to a benchmark fixture.

A fixture that will not decode stops the run. `Snapshot.at` over an empty race
measures nothing and still returns a time.

-}

import Data.Wec as Wec
import Data.Wec.Laps as Laps
import Generated.Manufacturer.Wec
import Json.Decode as Decode
import Motorsport.Chart.Tracker.Config exposing (MiniSectorShares(..))
import Motorsport.MiniSector as MiniSector
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car
import Motorsport.Wec.Era as Era


{-| The summary, with the era its season belongs to, the manufacturer table the
app compiles, and no photograph for any car.
-}
event : String -> Wec.Event
event summary =
    case Decode.decodeString (Wec.eventDecoder Era.Gt3AsThirdClass Generated.Manufacturer.Wec.table (always Nothing)) summary of
        Ok decoded ->
            decoded

        Err problem ->
            Debug.todo ("the fixture's summary did not decode: " ++ Decode.errorToString problem)


{-| The track order the round's shares name its mini-sectors in, which is the
order [`Laps.attach`](Data-Wec-Laps#attach) holds a lap's in. A round timed no
finer than three sectors has none.
-}
miniSectorNames : Wec.Event -> List String
miniSectorNames summary =
    case summary.track.config.miniSectors of
        NoMiniSectors ->
            []

        MiniSectorShares shares ->
            MiniSector.names shares


{-| The race a summary and its laps make: the entry list, its laps attached, and
the indices the summary spells out.
-}
decode : { summary : String, laps : String } -> Race
decode raw =
    case Laps.fromJsonl raw.laps of
        Ok rawLaps ->
            let
                summary =
                    event raw.summary
            in
            summary.startingGrid.entries
                |> List.map Car.fromStartingGrid
                |> Laps.attach (miniSectorNames summary) rawLaps
                |> Race.fromCars { timeLimit = summary.timeLimit, index = summary.index }

        Err problem ->
            Debug.todo ("the fixture's laps did not decode: " ++ problem)
