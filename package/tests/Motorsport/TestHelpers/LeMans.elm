module Motorsport.TestHelpers.LeMans exposing (map, geometry, layout)

{-| The Circuit de la Sarthe as the app draws it: the geometry it serves and the map record its bundle carries, each read through the app's own decoder.
-}

import Json.Decode as Decode
import Motorsport.TestHelpers.Map.LeMans as MapBytes
import Motorsport.TestHelpers.Survey.LeMans as SurveyBytes
import Motorsport.Wec.Circuit.Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Layout exposing (Layout)
import Motorsport.Wec.Circuit.LeMans.Layout as LeMansLayout exposing (CircuitMap)


map : Result String CircuitMap
map =
    Decode.decodeString LeMansLayout.mapDecoder MapBytes.text
        |> Result.mapError Decode.errorToString


geometry : Result String Geometry
geometry =
    map
        |> Result.andThen
            (\figures ->
                Decode.decodeString (LeMansLayout.decoder figures) SurveyBytes.text
                    |> Result.mapError Decode.errorToString
            )


layout : Result String Layout
layout =
    Result.map2 LeMansLayout.layout map geometry
