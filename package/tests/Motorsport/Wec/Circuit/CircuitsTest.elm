module Motorsport.Wec.Circuit.CircuitsTest exposing (Circuit, circuits, tests)

{-| Every circuit the app draws, read from the map record and the geometry it serves through the app's own decoders: the survey checked through the drawing it is projected into, and each drawing's lengths against Le Mans's.
A circuit joins with a row in `circuits`.
-}

import Expect
import Json.Decode as Decode exposing (Decoder)
import Motorsport.Circuit.Layout exposing (Layout)
import Motorsport.Circuit.Shape as Shape
import Motorsport.TestHelpers.Map.Barcelona as BarcelonaMap
import Motorsport.TestHelpers.Map.Cota as CotaMap
import Motorsport.TestHelpers.Map.Fuji as FujiMap
import Motorsport.TestHelpers.Map.Imola as ImolaMap
import Motorsport.TestHelpers.Map.LeMans as LeMansMap
import Motorsport.TestHelpers.Map.Monza as MonzaMap
import Motorsport.TestHelpers.Map.SaoPaulo as SaoPauloMap
import Motorsport.TestHelpers.Map.Spa as SpaMap
import Motorsport.TestHelpers.Survey.Barcelona as BarcelonaSurvey
import Motorsport.TestHelpers.Survey.Cota as CotaSurvey
import Motorsport.TestHelpers.Survey.Fuji as FujiSurvey
import Motorsport.TestHelpers.Survey.Imola as ImolaSurvey
import Motorsport.TestHelpers.Survey.LeMans as LeMansSurvey
import Motorsport.TestHelpers.Survey.Monza as MonzaSurvey
import Motorsport.TestHelpers.Survey.SaoPaulo as SaoPauloSurvey
import Motorsport.TestHelpers.Survey.Spa as SpaSurvey
import Motorsport.TestHelpers.SurveySuite as SurveySuite
import Motorsport.Wec.Circuit.Barcelona.Layout as Barcelona
import Motorsport.Wec.Circuit.Cota.Layout as Cota
import Motorsport.Wec.Circuit.Fuji.Layout as Fuji
import Motorsport.Wec.Circuit.Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Imola.Layout as Imola
import Motorsport.Wec.Circuit.LeMans.Layout as LeMans
import Motorsport.Wec.Circuit.Map as Map
import Motorsport.Wec.Circuit.Monza.Layout as Monza
import Motorsport.Wec.Circuit.SaoPaulo.Layout as SaoPaulo
import Motorsport.Wec.Circuit.Spa.Layout as Spa
import Test exposing (Test, describe, test)


{-| One circuit as the app draws it. `box` is where the circuit stands on the earth.
-}
type alias Circuit =
    { name : String
    , box : { minLat : Float, maxLat : Float, minLon : Float, maxLon : Float }
    , read : Result String ( Geometry, Layout )
    }


circuits : List Circuit
circuits =
    [ { name = "Barcelona"
      , box = { minLat = 41.55, maxLat = 41.59, minLon = 2.24, maxLon = 2.28 }
      , read = drawn Map.intermediatesDecoder Barcelona.decoder Barcelona.layout BarcelonaMap.text BarcelonaSurvey.text
      }
    , { name = "COTA"
      , box = { minLat = 30.0, maxLat = 30.3, minLon = -97.8, maxLon = -97.5 }
      , read = drawn Map.intermediatesDecoder Cota.decoder Cota.layout CotaMap.text CotaSurvey.text
      }
    , { name = "Fuji"
      , box = { minLat = 35.364, maxLat = 35.377, minLon = 138.919, maxLon = 138.935 }
      , read = drawn Map.intermediatesDecoder Fuji.decoder Fuji.layout FujiMap.text FujiSurvey.text
      }
    , leMans
    , { name = "Monza"
      , box = { minLat = 45.61, maxLat = 45.632, minLon = 9.28, maxLon = 9.298 }
      , read = drawn Map.intermediatesDecoder Monza.decoder Monza.layout MonzaMap.text MonzaSurvey.text
      }
    , { name = "Spa"
      , box = { minLat = 50.427, maxLat = 50.447, minLon = 5.959, maxLon = 5.978 }
      , read = drawn Map.intermediatesDecoder Spa.decoder Spa.layout SpaMap.text SpaSurvey.text
      }
    , { name = "São Paulo"
      , box = { minLat = -23.707, maxLat = -23.696, minLon = -46.701, maxLon = -46.694 }
      , read = drawn Map.intermediatesDecoder SaoPaulo.decoder SaoPaulo.layout SaoPauloMap.text SaoPauloSurvey.text
      }
    , { name = "Imola"
      , box = { minLat = 44.336, maxLat = 44.346, minLon = 11.702, maxLon = 11.726 }
      , read = drawn Map.intermediatesDecoder Imola.decoder Imola.layout ImolaMap.text ImolaSurvey.text
      }
    ]


{-| The reference: every other circuit's lengths are read as a fraction of Le Mans's.
-}
leMans : Circuit
leMans =
    { name = "Le Mans"
    , box = { minLat = 47.9, maxLat = 48.0, minLon = 0.1, maxLon = 0.3 }
    , read = drawn LeMans.mapDecoder LeMans.decoder LeMans.layout LeMansMap.text LeMansSurvey.text
    }


{-| A circuit read the way `Shared` reads it: its map's record first, then its geometry checked against that map, then the two laid out.
-}
drawn : Decoder map -> (map -> Decoder Geometry) -> (map -> Geometry -> Layout) -> String -> String -> Result String ( Geometry, Layout )
drawn mapDecoder geometryDecoder layoutOf mapText geometryText =
    Decode.decodeString mapDecoder mapText
        |> Result.andThen (\map -> Decode.decodeString (geometryDecoder map) geometryText |> Result.map (\geometry -> ( geometry, layoutOf map geometry )))
        |> Result.mapError Decode.errorToString


tests : Test
tests =
    describe "the circuits the app draws"
        (leMansLengths :: List.map circuitTests circuits)


circuitTests : Circuit -> Test
circuitTests circuit =
    case ( circuit.read, Result.map Tuple.second leMans.read ) of
        ( Ok ( geometry, layout ), Ok reference ) ->
            describe circuit.name
                (SurveySuite.suite
                    { name = "its survey, as served"
                    , box = circuit.box
                    , frame = geometry.frame
                    , centreline = List.map (\point -> { lat = point.lat, lon = point.lon }) geometry.centreline
                    , pitLane = geometry.pitLane
                    , layout = layout
                    }
                    :: sizedAgainst reference circuit layout
                )

        ( Err problem, _ ) ->
            test (circuit.name ++ ": the map record and the geometry the app serves decode") <|
                \_ ->
                    Expect.fail problem

        ( _, Err problem ) ->
            test (circuit.name ++ ": Le Mans, which every drawing is measured against, decodes") <|
                \_ ->
                    Expect.fail problem


{-| Every circuit but Le Mans is drawn at Le Mans's sizes on the screen.
-}
sizedAgainst : Layout -> Circuit -> Layout -> List Test
sizedAgainst reference circuit layout =
    if circuit.name == leMans.name then
        []

    else
        [ test "every length is drawn at Le Mans's size on the screen" <|
            \_ ->
            -- Both circuits are drawn in one box, and each box is fitted by its own
            -- width: the row is narrower in proportion than either of them. A length
            -- therefore reaches the same pixels at both circuits when it stands at
            -- the ratio of the two widths. The margin is the one length held back at
            -- three tenths of Le Mans's, since it is added to that width and so moves
            -- what every ratio is taken over.
                let
                    expected =
                        boxWidth layout / boxWidth reference
                in
                ratios layout reference
                    |> List.filter (\( _, got ) -> abs (got - expected) > 0.01)
                    |> List.map (\( name, got ) -> name ++ " at " ++ String.fromFloat got ++ " against " ++ String.fromFloat expected)
                    |> Expect.equal []
        ]


{-| Every Le Mans snapshot was rendered with these, and every other circuit's set is read against them.
-}
leMansLengths : Test
leMansLengths =
    test "Le Mans is drawn at the lengths the tracker was measured at" <|
        \_ ->
            leMans.read
                |> Result.map (Tuple.second >> .lengths)
                |> Expect.equal
                    (Ok
                    { compact =
                        { margin = 150
                        , trackWidth = 22
                        , pitLaneWidth = 14
                        , startFinishLineExtension = 130
                        , startFinishLineStrokeWidth = 32
                        , sectorBoundaryOffset = 105
                        , sectorBoundaryStrokeWidth = 42
                        , carSize = 105
                        , labels = Nothing
                        }
                    , full =
                        { margin = 700
                        , trackWidth = 16
                        , pitLaneWidth = 10
                        , startFinishLineExtension = 160
                        , startFinishLineStrokeWidth = 22
                        , sectorBoundaryOffset = 108
                        , sectorBoundaryStrokeWidth = 32
                        , carSize = 97
                        , labels =
                            Just
                                { sectorRadius = 380
                                , sectorFontSize = 170
                                , miniSectorRadius = -170
                                , miniSectorFontSize = 120
                                , carRadius = 190
                                , carFontSize = 140
                                }
                        }
                    }
                    )


{-| The circuit as drawn: the width the tracker fits it into, in metres on the
ground. `Tracker`'s own `bounds` plus the margin the labels stand off in, which is
the axis both of these circuits are fitted by.
-}
boxWidth : Layout -> Float
boxWidth this =
    let
        xs =
            List.map .x (Shape.marks this.shape) ++ List.map .x this.pitLane
    in
    case ( List.minimum xs, List.maximum xs ) of
        ( Just lo, Just hi ) ->
            hi - lo + 2 * this.lengths.full.margin

        _ ->
            0


{-| Every `Full` length beside the reference circuit's, as a ratio. The names are
the ones a failing length is reported by.
-}
ratios : Layout -> Layout -> List ( String, Float )
ratios this reference =
    let
        own =
            this.lengths.full

        measured =
            reference.lengths.full

        names =
            case ( own.labels, measured.labels ) of
                ( Just a, Just b ) ->
                    [ ( "sectorRadius", a.sectorRadius / b.sectorRadius )
                    , ( "sectorFontSize", a.sectorFontSize / b.sectorFontSize )
                    , ( "miniSectorRadius", a.miniSectorRadius / b.miniSectorRadius )
                    , ( "miniSectorFontSize", a.miniSectorFontSize / b.miniSectorFontSize )
                    , ( "carRadius", a.carRadius / b.carRadius )
                    , ( "carFontSize", a.carFontSize / b.carFontSize )
                    ]

                _ ->
                    []
    in
    [ ( "trackWidth", own.trackWidth / measured.trackWidth )
    , ( "pitLaneWidth", own.pitLaneWidth / measured.pitLaneWidth )
    , ( "startFinishLineExtension", own.startFinishLineExtension / measured.startFinishLineExtension )
    , ( "startFinishLineStrokeWidth", own.startFinishLineStrokeWidth / measured.startFinishLineStrokeWidth )
    , ( "sectorBoundaryOffset", own.sectorBoundaryOffset / measured.sectorBoundaryOffset )
    , ( "sectorBoundaryStrokeWidth", own.sectorBoundaryStrokeWidth / measured.sectorBoundaryStrokeWidth )
    , ( "carSize", own.carSize / measured.carSize )
    ]
        ++ names

