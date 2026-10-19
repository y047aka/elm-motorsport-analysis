module Motorsport.Wec.Circuit.Cota.GeometryTest exposing (tests)

import Motorsport.TestHelpers.SurveySuite as SurveySuite exposing (Survey)
import Motorsport.Wec.Circuit.Cota.Geometry as Geometry
import Motorsport.Wec.Circuit.Cota.Layout exposing (layout)
import Test exposing (Test)


{-| The round the tracker draws at COTA, out of the survey OpenStreetMap holds.
The box is Austin's, near 30.13 N 97.64 W.
-}
survey : Survey
survey =
    { name = "Motorsport.Wec.Circuit.Cota.Geometry"
    , box = { minLat = 30.0, maxLat = 30.3, minLon = -97.8, maxLon = -97.5 }
    , frame = Geometry.frame
    , centreline = List.map (\point -> { lat = point.lat, lon = point.lon }) Geometry.centreline
    , pitLane = Geometry.pitLane
    , layout = layout
    }


tests : Test
tests =
    SurveySuite.suite survey
