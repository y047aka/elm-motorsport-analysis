module Data.Wec exposing (Class(..), classFromString, classToString)


type Class
    = LMH
    | LMP1
    | LMP2
    | LMGTE_Pro
    | LMGTE_Am
    | InnovativeCar


classFromString : String -> Maybe Class
classFromString class =
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

        "INNOVATIVE CAR" ->
            Just InnovativeCar

        _ ->
            Nothing


classToString : Class -> String
classToString class =
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

        InnovativeCar ->
            "INNOVATIVE CAR"
