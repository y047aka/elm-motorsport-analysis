module Motorsport.Wec.Circuit.Monza.GeometryTest exposing (tests)

{-| The round the tracker draws at Monza, read from the bytes the app
serves: the geometry checked through the drawing it is projected into.
-}

import Expect
import Json.Decode as Decode
import Motorsport.TestHelpers.Survey.Monza as Survey
import Motorsport.TestHelpers.SurveySuite as SurveySuite exposing (Survey)
import Motorsport.Wec.Circuit.Monza.Layout as Layout
import Test exposing (Test, test)


{-| The box is Monza's, near 45.62 N 9.29 E.
-}
survey : Result String Survey
survey =
    Decode.decodeString Layout.decoder Survey.text
        |> Result.map
            (\geometry ->
                { name = "Motorsport.Wec.Circuit.Monza.Geometry, as served"
                , box = { minLat = 45.61, maxLat = 45.632, minLon = 9.28, maxLon = 9.298 }
                , frame = geometry.frame
                , centreline = List.map (\point -> { lat = point.lat, lon = point.lon }) geometry.centreline
                , pitLane = geometry.pitLane
                , layout = Layout.layout geometry
                }
            )
        |> Result.mapError Decode.errorToString


tests : Test
tests =
    case survey of
        Ok built ->
            SurveySuite.suite built

        Err problem ->
            test "the geometry the app serves decodes" <|
                \_ ->
                    Expect.fail problem
