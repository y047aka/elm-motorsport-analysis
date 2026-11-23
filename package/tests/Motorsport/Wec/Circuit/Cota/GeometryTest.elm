module Motorsport.Wec.Circuit.Cota.GeometryTest exposing (tests)

{-| The round the tracker draws at COTA, read from the bytes the app serves:
the geometry checked through the drawing it is projected into.
-}

import Expect
import Motorsport.TestHelpers.Drawn as Drawn
import Motorsport.TestHelpers.Map.Cota as MapBytes
import Motorsport.TestHelpers.Survey.Cota as Survey
import Motorsport.TestHelpers.SurveySuite as SurveySuite exposing (Survey)
import Motorsport.Wec.Circuit.Cota.Layout as Layout
import Motorsport.Wec.Circuit.Map as Map
import Test exposing (Test, test)


{-| The box is Austin's, near 30.13 N 97.64 W.
-}
survey : Result String Survey
survey =
    Drawn.read Map.intermediatesDecoder Layout.decoder MapBytes.text Survey.text
        |> Result.map
            (\( map, geometry ) ->
                { name = "Motorsport.Wec.Circuit.Cota.Geometry, as served"
                , box = { minLat = 30.0, maxLat = 30.3, minLon = -97.8, maxLon = -97.5 }
                , frame = geometry.frame
                , centreline = List.map (\point -> { lat = point.lat, lon = point.lon }) geometry.centreline
                , pitLane = geometry.pitLane
                , layout = Layout.layout map geometry
                }
            )


tests : Test
tests =
    case survey of
        Ok built ->
            SurveySuite.suite built

        Err problem ->
            test "the geometry the app serves decodes" <|
                \_ ->
                    Expect.fail problem
