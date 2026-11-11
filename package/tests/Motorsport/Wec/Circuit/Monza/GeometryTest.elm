module Motorsport.Wec.Circuit.Monza.GeometryTest exposing (tests)

{-| The round the tracker draws at Monza, read from the bytes the app
serves: the geometry checked through the drawing it is projected into.
-}

import Expect
import Json.Decode as Decode
import Motorsport.Chart.Tracker.Config exposing (Share)
import Motorsport.Sector as Sector exposing (BySector, Sector(..))
import Motorsport.TestHelpers.Survey.Monza as Survey
import Motorsport.TestHelpers.SurveySuite as SurveySuite exposing (Survey)
import Motorsport.Wec.Circuit.Monza.Layout as Layout
import Test exposing (Test, test)


{-| The 2026 round's sector shares -- this circuit's lines are placed by a
round's own divisions. The suite checks the drawing, not the season.
-}
shares : BySector Share
shares =
    Sector.initialize
        (\sector ->
            case sector of
                S1 ->
                    { start = 0, share = 0.3192478813559322 }

                S2 ->
                    { start = 0.3192478813559322, share = 0.3407521186440678 }

                S3 ->
                    { start = 0.66, share = 0.34 }
        )


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
                , layout = Layout.layout geometry shares
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
