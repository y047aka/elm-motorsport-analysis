module Motorsport.Wec.Circuit.Barcelona.GeometryTest exposing (tests)

{-| The round the tracker draws at Barcelona, read from the bytes the app
serves: the geometry checked through the drawing it is projected into.
-}

import Expect
import Json.Decode as Decode
import Motorsport.Chart.Tracker.Config exposing (Share)
import Motorsport.Sector as Sector exposing (BySector, Sector(..))
import Motorsport.TestHelpers.Survey.Barcelona as Survey
import Motorsport.TestHelpers.SurveySuite as SurveySuite exposing (Survey)
import Motorsport.Wec.Circuit.Barcelona.Layout as Layout
import Test exposing (Test, test)


{-| The round's sector shares, which is what places this circuit's lines --
the circuit publishes no distances for them. The 2026 round's divisions; the
suite checks the drawing, not the season.
-}
shares : BySector Share
shares =
    Sector.initialize
        (\sector ->
            case sector of
                S1 ->
                    { start = 0, share = 0.2919102149018926 }

                S2 ->
                    { start = 0.2919102149018926, share = 0.405803872145325 }

                S3 ->
                    { start = 0.6977140870472176, share = 0.3022859129527824 }
        )


{-| The box is Montmeló's, near 41.57 N 2.26 E.
-}
survey : Result String Survey
survey =
    Decode.decodeString Layout.decoder Survey.text
        |> Result.map
            (\geometry ->
                { name = "Motorsport.Wec.Circuit.Barcelona.Geometry, as served"
                , box = { minLat = 41.55, maxLat = 41.59, minLon = 2.24, maxLon = 2.28 }
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
