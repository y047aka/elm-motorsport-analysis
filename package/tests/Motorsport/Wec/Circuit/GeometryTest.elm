module Motorsport.Wec.Circuit.GeometryTest exposing (tests)

{-| What the decoder does with bytes it should not accept, on geometries
written here; the kept files themselves are read by `CircuitsTest`.
-}

import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Length
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
        , test "the first metre must stand at the finish line" <|
            \_ ->
                decode { outline | metres = [ 1, 5, 10 ] }
                    |> complainsAbout "does not start at the finish line"
        , test "an outline that does not come back to where it started is no lap" <|
            \_ ->
                [ outlineFeature outline (line [ ( 47.9, 0.1 ), ( 47.9, 0.2 ), ( 47.91, 0.2 ) ]), pitLane ]
                    |> decodeOf
                    |> complainsAbout "does not close"
        , test "an outline that ends exactly where the circuit says is read" <|
            \_ ->
                decode outline
                    |> Result.map (.centreline >> List.reverse >> List.head >> Maybe.map .metres)
                    |> Expect.equal (Ok (Just (Length.meters 10.0)))
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
        , test "an outline that cannot say which way it runs is not surveyed" <|
            \_ ->
                decode { outline | direction = Nothing }
                    |> complainsAbout "names no direction"
        , test "a direction spelled some third way is a disagreement, not a half-turn" <|
            \_ ->
                decode { outline | direction = Just "anticlockwise" }
                    |> complainsAbout "says it runs anticlockwise"
        , test "the heights beside both lines are read, one per point" <|
            \_ ->
                heighted (Just [ 150, 160, 150 ]) (Just [ 151, 152 ])
                    |> Result.map .heights
                    |> Expect.equal (Ok (Just { centreline = List.map Length.meters [ 150, 160, 150 ], pitLane = List.map Length.meters [ 151, 152 ] }))
        , test "a geometry carrying no heights is read as one standing flat" <|
            \_ ->
                decode outline
                    |> Result.map .heights
                    |> Expect.equal (Ok Nothing)
        , test "a height out of step with its points is refused" <|
            \_ ->
                heighted (Just [ 150, 160 ]) (Just [ 151, 152 ])
                    |> complainsAbout "2 heights for the outline's 3 points"
        , test "heights on one line and not the other are refused" <|
            \_ ->
                heighted (Just [ 150, 160, 150 ]) Nothing
                    |> complainsAbout "one line carries heights and the other does not"
        , test "a role drawn as a point is no line, and so no outline" <|
            \_ ->
                decodeOf [ outlineFeature outline (point [ 0.2, 47.9 ]), pitLane ]
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        ]



-- A three-point lap of ten metres, out and back to where it started, in the shape `geoJsonString` writes.


type alias Lap =
    { metres : List Float
    , frame : Maybe Encode.Value
    , direction : Maybe String
    }


outline : Lap
outline =
    { metres = [ 0, 5, 10 ]
    , frame = Just frame
    , direction = Just "clockwise"
    }


frame : Encode.Value
frame =
    Encode.object
        [ ( "origin", Encode.object [ ( "lat", Encode.float 47.9 ), ( "lon", Encode.float 0.1 ) ] )
        , ( "parallel", Encode.float 0.669139 )
        ]


features : List Encode.Value -> Lap -> List Encode.Value
features extra lap =
    [ outlineFeature lap (line [ ( 47.9, 0.1 ), ( 47.9, 0.2 ), ( 47.9, 0.1 ) ]) ]
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
                        ++ Maybe.withDefault [] (Maybe.map (\d -> [ ( "direction", Encode.string d ) ]) lap.direction)
                   )
          )
        , ( "geometry", geometry )
        ]


{-| The lap and the pit lane, each carrying the heights given as its `elevation_m`.
-}
heighted : Maybe (List Float) -> Maybe (List Float) -> Result String Geometry.Geometry
heighted lap pit =
    let
        withHeights heights feature =
            case ( heights, Decode.decodeValue (Decode.keyValuePairs Decode.value) feature ) of
                ( Just these, Ok members ) ->
                    members
                        |> List.map
                            (\( key, value ) ->
                                if key == "properties" then
                                    ( key
                                    , Decode.decodeValue (Decode.keyValuePairs Decode.value) value
                                        |> Result.withDefault []
                                        |> (\props -> Encode.object (props ++ [ ( "elevation_m", Encode.list Encode.float these ) ]))
                                    )

                                else
                                    ( key, value )
                            )
                        |> Encode.object

                _ ->
                    feature
    in
    decodeOf
        [ withHeights lap (outlineFeature outline (line [ ( 47.9, 0.1 ), ( 47.9, 0.2 ), ( 47.9, 0.1 ) ]))
        , withHeights pit pitLane
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
        |> Decode.decodeString (Geometry.decoder { lapLength = Length.meters 10 })
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
