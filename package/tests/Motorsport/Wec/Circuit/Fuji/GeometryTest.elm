module Motorsport.Wec.Circuit.Fuji.GeometryTest exposing (tests)

{-| The round the tracker draws at Fuji, read from the bytes the app
serves: the geometry checked through the drawing it is projected into.
-}

import Expect
import Json.Decode as Decode
import Motorsport.Chart.Tracker.Config exposing (Share)
import Motorsport.Sector as Sector exposing (BySector, Sector(..))
import Motorsport.TestHelpers.Survey.Fuji as Survey
import Motorsport.TestHelpers.SurveySuite as SurveySuite exposing (Survey)
import Motorsport.Wec.Circuit.Fuji.Layout as Layout
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
                    { start = 0, share = 0.24390513449594414 }

                S2 ->
                    { start = 0.24390513449594414, share = 0.31201511836085144 }

                S3 ->
                    { start = 0.5559202528567956, share = 0.44407974714320453 }
        )


{-| The box is Fuji's, near 35.37 N 138.93 E.
-}
survey : Result String Survey
survey =
    Decode.decodeString Layout.decoder Survey.text
        |> Result.map
            (\geometry ->
                { name = "Motorsport.Wec.Circuit.Fuji.Geometry, as served"
                , box = { minLat = 35.364, maxLat = 35.377, minLon = 138.919, maxLon = 138.935 }
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
