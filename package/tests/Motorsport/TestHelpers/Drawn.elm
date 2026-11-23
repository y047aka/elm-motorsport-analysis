module Motorsport.TestHelpers.Drawn exposing (read)

{-| A circuit read the way the app reads it: its map's record first, then its geometry checked against that map.
-}

import Json.Decode as Decode exposing (Decoder)
import Motorsport.Wec.Circuit.Geometry exposing (Geometry)


read : Decoder map -> (map -> Decoder Geometry) -> String -> String -> Result String ( map, Geometry )
read mapDecoder geometryDecoder mapText geometryText =
    Decode.decodeString mapDecoder mapText
        |> Result.andThen (\map -> Decode.decodeString (geometryDecoder map) geometryText |> Result.map (Tuple.pair map))
        |> Result.mapError Decode.errorToString
