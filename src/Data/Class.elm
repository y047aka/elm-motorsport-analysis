module Data.Class exposing (Class(..), fromString, toString)


type Class
    = LMH
    | LMP1
    | LMP2
    | LMGTE_Pro
    | LMGTE_Am


fromString : String -> Maybe Class
fromString class =
    case class of
        "HYPERCAR" ->
            Just LMH

        "LMP1" ->
            Just LMP1

        "LMP2" ->
            Just LMP2

        "LMGTE Pro" ->
            Just LMGTE_Pro

        "LMGTE Am" ->
            Just LMGTE_Am

        _ ->
            Nothing


toString : Class -> String
toString class =
    case class of
        LMH ->
            "HYPERCAR"

        LMP1 ->
            "LMP1"

        LMP2 ->
            "LMP2"

        LMGTE_Pro ->
            "LMGTE Pro"

        LMGTE_Am ->
            "LMGTE Am"
