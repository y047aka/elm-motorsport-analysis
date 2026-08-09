module Data.Series.Wec exposing
    ( Wec(..), fromString, toString
    , direction
    )

{-|

@docs Wec, fromString, toString
@docs direction

-}

import Motorsport.Circuit.Direction exposing (Direction(..))


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


{-| Which way round a round's circuit goes -- the only thing about a circuit
this side still has to know, now that how the lap divides and how long each
division is both arrive in the summary.

Keyed by the round rather than by its name, which is what
`Chart.Tracker` used to match on -- a list of three event names that had to be
kept in step with the calendar by hand, and that said nothing at all for a name
not on it. Here the compiler will not let a round go unanswered.

The season does not come into it. It used to, for Le Mans alone, because 2025 is
the one running of it the source data splits into mini-sectors -- but that is a
fact about the file, which the CLI reads off the file itself.

-}
direction : Wec -> Direction
direction event =
    case event of
        Qatar_1812km ->
            Clockwise

        Imola_6h ->
            CounterClockwise

        Spa_6h ->
            Clockwise

        LeMans_24h ->
            Clockwise

        SaoPaulo_6h ->
            CounterClockwise

        Cota_6h ->
            CounterClockwise

        Fuji_6h ->
            Clockwise

        Bahrain_8h ->
            Clockwise
