module Motorsport.TestHelpers.LeMans exposing (map, geometry, layout)

{-| The Circuit de la Sarthe as the app draws it: the map record and the geometry it serves, each read through the app's own decoder.
-}

import Motorsport.TestHelpers.Drawn as Drawn
import Motorsport.TestHelpers.Map.LeMans as MapBytes
import Motorsport.TestHelpers.Survey.LeMans as SurveyBytes
import Motorsport.Wec.Circuit.Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Layout exposing (Layout)
import Motorsport.Wec.Circuit.LeMans.Layout as LeMansLayout exposing (CircuitMap)


read : Result String ( CircuitMap, Geometry )
read =
    Drawn.read LeMansLayout.mapDecoder LeMansLayout.decoder MapBytes.text SurveyBytes.text


map : Result String CircuitMap
map =
    Result.map Tuple.first read


geometry : Result String Geometry
geometry =
    Result.map Tuple.second read


layout : Result String Layout
layout =
    Result.map (\( figures, lap ) -> LeMansLayout.layout figures lap) read
