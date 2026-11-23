module Motorsport.Wec.Circuit.Barcelona.GeometryTest exposing (tests)

{-| The round the tracker draws at Barcelona, read from the bytes the app
serves: the geometry checked through the drawing it is projected into.
-}

import Expect
import Motorsport.TestHelpers.Drawn as Drawn
import Motorsport.TestHelpers.Map.Barcelona as MapBytes
import Motorsport.TestHelpers.Survey.Barcelona as Survey
import Motorsport.TestHelpers.SurveySuite as SurveySuite exposing (Survey)
import Motorsport.Wec.Circuit.Barcelona.Layout as Layout
import Motorsport.Wec.Circuit.Map as Map
import Test exposing (Test, test)


{-| The box is Montmeló's, near 41.57 N 2.26 E.
-}
survey : Result String Survey
survey =
    Drawn.read Map.intermediatesDecoder Layout.decoder MapBytes.text Survey.text
        |> Result.map
            (\( map, geometry ) ->
                { name = "Motorsport.Wec.Circuit.Barcelona.Geometry, as served"
                , box = { minLat = 41.55, maxLat = 41.59, minLon = 2.24, maxLon = 2.28 }
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
