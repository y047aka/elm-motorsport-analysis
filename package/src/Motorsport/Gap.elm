module Motorsport.Gap exposing (Gap(..), at, toString)

import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap as Lap


type Gap
    = None
    | Seconds Duration
    | Laps Int


at : Clock.Model -> Car -> Car -> Gap
at clock carA carB =
    case lapDiffAt clock carA carB of
        0 ->
            secondsAt clock carA carB

        laps ->
            Laps laps


lapDiffAt : Clock.Model -> Car -> Car -> Duration
lapDiffAt clock carA carB =
    let
        diff =
            Maybe.map2 (\lapA lapB -> lapA.lap - lapB.lap) carA.currentLap carB.currentLap

        raceClock =
            { elapsed = Clock.getElapsed clock }

        currentSector =
            carB.currentLap
                |> Maybe.map (Lap.currentSector raceClock)

        isNotLapped =
            case ( Maybe.map2 Lap.sectorToElapsed carA.currentLap currentSector, Maybe.map2 Lap.sectorToElapsed carB.currentLap currentSector ) of
                ( Just a, Just b ) ->
                    a >= b

                _ ->
                    False
    in
    case ( diff, isNotLapped ) of
        ( Just 0, _ ) ->
            0

        ( Just nonzero, True ) ->
            nonzero - 1

        ( Just nonzero, False ) ->
            nonzero

        ( Nothing, _ ) ->
            0


secondsAt : Clock.Model -> Car -> Car -> Gap
secondsAt clock carA carB =
    let
        raceClock =
            { elapsed = Clock.getElapsed clock }

        carB_currentSector =
            carB.currentLap
                |> Maybe.map (Lap.currentSector raceClock)

        targetLap =
            List.Extra.getAt ((carB.currentLap |> Maybe.map .lap |> Maybe.withDefault 0) - 1) carA.laps
    in
    case ( carB_currentSector, targetLap, carB.currentLap ) of
        ( Just sector, Just targetLap_, Just currentLap ) ->
            Seconds (Lap.sectorToElapsed currentLap sector - Lap.sectorToElapsed targetLap_ sector)

        _ ->
            None


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
