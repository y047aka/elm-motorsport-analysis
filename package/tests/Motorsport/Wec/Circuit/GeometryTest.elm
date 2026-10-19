module Motorsport.Wec.Circuit.GeometryTest exposing (tests)

{-| The decoder that reads a served geometry, on geometries written here: the
bytes the pipeline actually writes are read by each circuit's own `GeometryTest`
against its kept file; what is checked here is what the decoder does with bytes
it should not accept.
-}

import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Motorsport.Wec.Circuit.Geometry as Geometry
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Motorsport.Wec.Circuit.Geometry"
        [ test "a geometry reads whole: the lap with its distances, the pit lane without" <|
            \_ ->
                decode outline
                    |> Result.map (\geometry -> ( List.length geometry.centreline, List.length geometry.pitLane ))
                    |> Expect.equal (Ok ( 3, 2 ))
        , test "a metre per point is required, not a polite suggestion" <|
            \_ ->
                decode { outline | metres = [ 0, 5 ] }
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "metres going backwards is the outline's own contradiction" <|
            \_ ->
                decode { outline | metres = [ 0, 10, 5 ] }
                    |> complainsAbout "backwards"
        , test "the last metre must stand at the published lap length" <|
            \_ ->
                decode { outline | metres = [ 0, 5, 9.5 ] }
                    |> complainsAbout "not the published"
        , test "an outline that ends exactly where the circuit says is read" <|
            \_ ->
                decode outline
                    |> Result.map (.centreline >> List.reverse >> List.head >> Maybe.map .metres)
                    |> Expect.equal (Ok (Just 10.0))
        , test "a geometry without a pit lane is not a geometry" <|
            \_ ->
                { outline | metres = [ 0, 5, 10 ] }
                    |> features []
                    |> decodeOf
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "an outline carrying no frame cannot be projected" <|
            \_ ->
                decode { outline | frame = Nothing }
                    |> complainsAbout "no metres or no frame"
        , test "a role drawn as a point is no line, and so no outline" <|
            \_ ->
                decodeOf [ outlineFeature outline (point [ 0.2, 47.9 ]), pitLane ]
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        ]



-- A three-point lap of ten metres, in the shape `geoJsonString` writes.


type alias Lap =
    { metres : List Float
    , frame : Maybe Encode.Value
    }


outline : Lap
outline =
    { metres = [ 0, 5, 10 ]
    , frame = Just frame
    }


frame : Encode.Value
frame =
    Encode.object
        [ ( "origin", Encode.object [ ( "lat", Encode.float 47.9 ), ( "lon", Encode.float 0.1 ) ] )
        , ( "parallel", Encode.float 0.669139 )
        ]


features : List Encode.Value -> Lap -> List Encode.Value
features extra lap =
    [ outlineFeature lap (line [ ( 47.9, 0.1 ), ( 47.9, 0.2 ), ( 47.91, 0.2 ) ]) ]
        ++ extra


outlineFeature : Lap -> Encode.Value -> Encode.Value
outlineFeature lap geometry =
    Encode.object
        [ ( "type", Encode.string "Feature" )
        , ( "properties",
                Encode.object
                    ([ ( "role", Encode.string "outline" )
                     , ( "metres", Encode.list Encode.float lap.metres )
                     ]
                        ++ Maybe.withDefault [] (Maybe.map (\f -> [ ( "frame", f ) ]) lap.frame)
                   )
          )
        , ( "geometry", geometry )
        ]


point : List Float -> Encode.Value
point coordinates =
    Encode.object [ ( "type", Encode.string "Point" ), ( "coordinates", Encode.list Encode.float coordinates ) ]


pitLane : Encode.Value
pitLane =
    Encode.object
        [ ( "type", Encode.string "Feature" )
        , ( "properties", Encode.object [ ( "role", Encode.string "pit_lane" ) ] )
        , ( "geometry", line [ ( 47.9, 0.11 ), ( 47.905, 0.115 ) ] )
        ]


line : List ( Float, Float ) -> Encode.Value
line places =
    Encode.object
        [ ( "type", Encode.string "LineString" )
        , ( "coordinates", Encode.list coordinate places )
        ]


coordinate : ( Float, Float ) -> Encode.Value
coordinate ( lat, lon ) =
    Encode.list Encode.float [ lon, lat ]


decode : Lap -> Result String Geometry.Geometry
decode lap =
    decodeOf (features [ pitLane ] lap)


decodeOf : List Encode.Value -> Result String Geometry.Geometry
decodeOf all =
    Encode.object [ ( "type", Encode.string "FeatureCollection" ), ( "features", Encode.list identity all ) ]
        |> Encode.encode 0
        |> Decode.decodeString (Geometry.decoder { lapLength = 10 })
        |> Result.mapError Decode.errorToString


complainsAbout : String -> Result String a -> Expect.Expectation
complainsAbout phrase read =
    case read of
        Err problem ->
            if String.contains phrase problem then
                Expect.pass

            else
                Expect.fail ("it did complain, but not about that: " ++ problem)

        Ok _ ->
            Expect.fail "it read a geometry it should have refused"
