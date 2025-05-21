module Data.Series.Wec exposing (Wec(..), fromString, toString)

{-|

@docs Wec, fromString, toString

-}


type Wec
    = Qatar_1812km
    | Imola_6h
    | Spa_6h
    | LeMans_24h
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

        Fuji_6h ->
            "fuji_6h"

        Bahrain_8h ->
            "bahrain_8h"
