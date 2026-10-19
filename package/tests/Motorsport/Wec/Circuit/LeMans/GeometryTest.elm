module Motorsport.Wec.Circuit.LeMans.GeometryTest exposing (tests)

import Motorsport.TestHelpers.SurveySuite as SurveySuite exposing (Survey)
import Motorsport.Wec.Circuit.LeMans.Geometry as Geometry
import Motorsport.Wec.Circuit.LeMans.Layout exposing (layout)
import Test exposing (Test)


{-| 2025's Le Mans: the round a checkout keeps, and the shape every view draws.
The survey's box is the Circuit de la Sarthe's, near 47.98 N 0.21 E.
-}
survey : Survey
survey =
    { name = "Motorsport.Wec.Circuit.LeMans.Geometry"
    , box = { minLat = 47.9, maxLat = 48.0, minLon = 0.1, maxLon = 0.3 }
    , frame = Geometry.frame
    , centreline = List.map (\point -> { lat = point.lat, lon = point.lon }) Geometry.centreline
    , pitLane = Geometry.pitLane
    , layout = layout 2025
    }


tests : Test
tests =
    SurveySuite.suite survey
