module Motorsport.Gap exposing (Gap(..), from, toString)

import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)


type Gap
    = None
    | Seconds Duration
    | Laps Int


from : Lap -> Lap -> Gap
from a b =
    case ( a.lap - b.lap, b.elapsed - a.elapsed ) of
        ( 0, 0 ) ->
            None

        ( 0, seconds ) ->
            Seconds seconds

        ( laps, _ ) ->
            Laps laps


toString : Gap -> String
toString gap =
    case gap of
        None ->
            "-"

        Seconds duration ->
            "+ " ++ Duration.toString duration

        Laps 1 ->
            "+ 1 Lap"

        Laps count ->
            "+ " ++ String.fromInt count ++ " Laps"
