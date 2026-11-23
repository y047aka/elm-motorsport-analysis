module Motorsport.Wec.Circuit.LeMans.GeometryTest exposing (tests)

{-| 2025's Le Mans: the round a checkout keeps, read from the bytes the app
serves: the geometry checked through the drawing it is projected into.
-}

import Expect
import Motorsport.TestHelpers.LeMans as LeMansFixture
import Motorsport.TestHelpers.SurveySuite as SurveySuite exposing (Survey)
import Test exposing (Test, test)


{-| The survey's box is the Circuit de la Sarthe's, near 47.98 N 0.21 E.
-}
survey : Result String Survey
survey =
    Result.map2
        (\geometry layout ->
            { name = "Motorsport.Wec.Circuit.LeMans.Geometry, as served"
            , box = { minLat = 47.9, maxLat = 48.0, minLon = 0.1, maxLon = 0.3 }
            , frame = geometry.frame
            , centreline = List.map (\point -> { lat = point.lat, lon = point.lon }) geometry.centreline
            , pitLane = geometry.pitLane
            , layout = layout
            }
        )
        LeMansFixture.geometry
        LeMansFixture.layout


tests : Test
tests =
    case survey of
        Ok built ->
            SurveySuite.suite built

        Err problem ->
            test "the geometry the app serves decodes" <|
                \_ ->
                    Expect.fail problem
