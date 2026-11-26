module Motorsport.Chart.Tracker exposing (Track, fromConfig, onCircuit, view, circuit)

{-| The field drawn going round the circuit: on the circuit's own shape where the app has a map of it, and on the [`Ring`](Motorsport-Chart-Tracker-Ring) the summary's proportions describe where it has none.

Hold on to a `Track` and hand it to [`view`](#view) each frame.

@docs Track, fromConfig, onCircuit, view, circuit

-}

import Motorsport.Chart.Tracker.Circuit as Circuit exposing (Circuit)
import Motorsport.Chart.Tracker.Config exposing (TrackConfig)
import Motorsport.Chart.Tracker.Detail exposing (Detail)
import Motorsport.Chart.Tracker.Ring as Ring
import Motorsport.Circuit.Direction exposing (Direction)
import Motorsport.Race.Snapshot exposing (Snapshot)
import Motorsport.Wec.Circuit.Layout exposing (Layout)
import Svg exposing (Svg)


type Track
    = Ring TrackConfig
    | OnCircuit Circuit


fromConfig : TrackConfig -> Track
fromConfig =
    Ring


{-| See [`Circuit.fromLayout`](Motorsport-Chart-Tracker-Circuit#fromLayout).
-}
onCircuit : Layout -> { direction : Direction, config : TrackConfig } -> Track
onCircuit layout placing =
    OnCircuit (Circuit.fromLayout layout placing)


view : Detail -> Track -> Snapshot -> Svg msg
view detail shown standings =
    case shown of
        Ring config ->
            Ring.view detail config standings

        OnCircuit drawn ->
            Circuit.view detail drawn standings


{-| The circuit's own shape, where the app has a map of it.
-}
circuit : Track -> Maybe Circuit
circuit shown =
    case shown of
        Ring _ ->
            Nothing

        OnCircuit drawn ->
            Just drawn
