module Motorsport.Wec.Circuit.LeMansPaceTest exposing (tests)

{-| The reference lap of Le Mans as served, against the share of the lap the 2025 24 Hours' summary gives each stretch between the lines its map gives a distance for.
-}

import Expect
import Json.Decode as Decode
import Motorsport.Circuit.Pace as Pace exposing (Pace)
import Motorsport.Circuit.Shape as Shape
import Motorsport.TestHelpers.Map.LeMans as LeMansMap
import Motorsport.TestHelpers.Survey.LeMans as LeMansSurvey
import Motorsport.Wec.Circuit.Layout exposing (MiniSectorLines(..))
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector(..))
import Motorsport.Wec.Circuit.LeMans.Layout as Layout
import Test exposing (Test, describe, test)


{-| Where each line ends its stretch, as a share of the lap: `app/static/wec/2025/le_mans_24h.json`'s `track.miniSectors`, `start + share`.
-}
shares2025 : List ( LeMans2025MiniSector, Float )
shares2025 =
    [ ( IP1, 0.1577 )
    , ( IP2, 0.543 )
    , ( PORIN, 0.8324 )
    , ( POROUT, 0.9049 )
    , ( SCL1, 0.9544 )
    , ( FORDOUT, 0.9833 )
    , ( FL, 1 )
    ]


tests : Test
tests =
    let
        layout =
            Decode.decodeString Layout.mapDecoder LeMansMap.text
                |> Result.andThen (\map -> Decode.decodeString (Layout.decoder map) LeMansSurvey.text |> Result.map (Layout.layout map))
    in
    describe "Le Mans's reference lap"
        [ test "spends the lap between its lines closer to the 2025 race than an even pace does" <|
            \_ ->
                case layout of
                    Ok { shape, timingLines } ->
                        case timingLines.miniSectors of
                            LeMansMiniSectors lines ->
                                let
                                    distances =
                                        List.filterMap (\( mini, share ) -> LeMans.get mini lines |> Maybe.map (\metres -> ( metres, share ))) shares2025
                                in
                                ( missedBy (Pace.fromShape shape) (Shape.length shape) distances
                                , missedBy Pace.even (Shape.length shape) distances
                                )
                                    |> Expect.all
                                        [ \_ -> Expect.equal (List.length shares2025) (List.length distances)
                                        , Tuple.first >> Expect.atMost 0.03
                                        , Tuple.second >> Expect.atLeast 0.09
                                        ]

                            SectorsOnly ->
                                Expect.fail "Le Mans places its mini-sectors' lines"

                    Err problem ->
                        Expect.fail (Decode.errorToString problem)
        ]


{-| How far, summed over the stretches, the share of the lap a pace spends on each stretch is from the share the race did.
-}
missedBy : Pace -> Float -> List ( Float, Float ) -> Float
missedBy pace lapLength lines =
    let
        lapSeconds =
            Pace.secondsAt pace lapLength

        stretches ends =
            List.map2 (-) ends (0 :: ends)
    in
    List.map2 (\a b -> abs (a - b))
        (stretches (List.map (\( metres, _ ) -> Pace.secondsAt pace metres / lapSeconds) lines))
        (stretches (List.map Tuple.second lines))
        |> List.sum
