module Data.Series.Wec exposing
    ( Wec(..), fromString, toString
    , circuit
    )

{-|

@docs Wec, fromString, toString
@docs circuit

-}

import Motorsport.Circuit as Circuit exposing (Layout)
import Motorsport.Wec.Circuit.LeMans exposing (LeMans2025MiniSector)


type Wec
    = Qatar_1812km
    | Imola_6h
    | Spa_6h
    | LeMans_24h
    | SaoPaulo_6h
    | Cota_6h
    | Fuji_6h
    | Bahrain_8h


fromString : String -> Maybe Wec
fromString string =
    case string of
        "qatar_1812km" ->
            Just Qatar_1812km

        "imola_6h" ->
            Just Imola_6h

        "spa_6h" ->
            Just Spa_6h

        "le_mans_24h" ->
            Just LeMans_24h

        "sao_paulo_6h" ->
            Just SaoPaulo_6h

        "cota_6h" ->
            Just Cota_6h

        "fuji_6h" ->
            Just Fuji_6h

        "bahrain_8h" ->
            Just Bahrain_8h

        _ ->
            Nothing


toString : Wec -> String
toString event =
    case event of
        Qatar_1812km ->
            "qatar_1812km"

        Imola_6h ->
            "imola_6h"

        Spa_6h ->
            "spa_6h"

        LeMans_24h ->
            "le_mans_24h"

        SaoPaulo_6h ->
            "sao_paulo_6h"

        Cota_6h ->
            "cota_6h"

        Fuji_6h ->
            "fuji_6h"

        Bahrain_8h ->
            "bahrain_8h"


{-| The circuit a round is run on.

Keyed by the round rather than by its name, which is what
`Chart.Tracker` used to match on -- a list of three event names that had to be
kept in step with the calendar by hand, and that said nothing at all for a name
not on it. Here the compiler will not let a round go unanswered.

The season comes into it for Le Mans alone: `leMans2025` is the mini-sector
layout of that year's race, and that is the only running of it the source data
splits into mini-sectors. Every other round is timed to sectors only, and
differs just in which way the cars go round.

-}
circuit : { season : Int, event : Wec } -> Layout LeMans2025MiniSector
circuit { season, event } =
    case event of
        Qatar_1812km ->
            Circuit.clockwise

        Imola_6h ->
            Circuit.counterClockwise

        Spa_6h ->
            Circuit.clockwise

        LeMans_24h ->
            if season == 2025 then
                Circuit.leMans2025

            else
                Circuit.clockwise

        SaoPaulo_6h ->
            Circuit.counterClockwise

        Cota_6h ->
            Circuit.counterClockwise

        Fuji_6h ->
            Circuit.clockwise

        Bahrain_8h ->
            Circuit.clockwise
