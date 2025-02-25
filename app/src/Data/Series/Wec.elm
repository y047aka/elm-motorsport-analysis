module Data.Series.Wec exposing
    ( Wec(..), fromString, toString
    , EventSummary
    )

{-|

@docs Wec, fromString, toString
@docs EventSummary

-}


type Wec
    = LeMans_24h
    | Fuji_6h
    | Bahrain_8h


fromString : String -> Maybe Wec
fromString string =
    case string of
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
        LeMans_24h ->
            "le_mans_24h"

        Fuji_6h ->
            "fuji_6h"

        Bahrain_8h ->
            "bahrain_8h"


type alias EventSummary =
    { id : String
    , name : String
    , date : String
    , jsonPath : String
    }
