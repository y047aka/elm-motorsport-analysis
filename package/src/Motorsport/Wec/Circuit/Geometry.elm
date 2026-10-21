module Motorsport.Wec.Circuit.Geometry exposing (Geometry, LapPoint, decoder)

{-| The geometry a circuit is drawn from, as its served file holds it: the
surveyed degrees, how far round the lap each stands, and the
[`Frame`](Motorsport-Circuit-Geodesy#Frame) to project them through.

The file is written by the pipeline in `app/scripts` and served under
`/static/geometry/`, named by the word the summaries send for the circuit.
[`decoder`](#decoder) checks the bytes as they arrive: a served file can be
stale, truncated, or -- in a Tauri bundle -- the app shell the asset resolver
answers for a path it does not know. A geometry that fails here fails as the
round's own load failure rather than as a drawing that quietly lacks a circuit.

The last metre must stand where the circuit's published lap length says --
the one number the file cannot vouch for itself, which is why the decoder is
given it.

The RFC layer is `mgold/elm-geojson`; what is read here is what that cannot
know: the `role`s this file uses, the metres beside the points, the frame, the
direction the survey runs, the published length.

@docs Geometry, LapPoint, decoder

-}

import GeoJson
import Json.Decode as Decode exposing (Decoder)
import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Circuit.Geodesy as Geodesy exposing (Coordinate, Frame)


{-| A point of the lap: where it stands on the earth, and how far round the lap
it is.
-}
type alias LapPoint =
    { lat : Float
    , lon : Float
    , metres : Float
    }


{-| One circuit's drawn lines and the frame they project through.
-}
type alias Geometry =
    { frame : Frame
    , direction : Direction
    , centreline : List LapPoint
    , pitLane : List Coordinate
    }


{-| Read a served geometry, checking it against the lap length the circuit
publishes: one metre per point, none going backwards, and the last one standing
at the published length.

The file's own `sectors` are not read or checked here: nothing in a drawing is
placed by them, and `check-timing-lines.mjs` is the reader that judges them.

-}
decoder : { lapLength : Float } -> Decoder Geometry
decoder { lapLength } =
    GeoJson.decoder
        |> Decode.andThen
            (\( collection, _ ) ->
                case collection of
                    GeoJson.FeatureCollection features ->
                        assemble lapLength (List.filterMap line features)

                    _ ->
                        Decode.fail "the geometry is not a feature collection"
            )


{-| The features that matter: a known `role`, with a line as its geometry.
-}
line : GeoJson.FeatureObject -> Maybe Feature
line feature =
    case ( Decode.decodeValue (Decode.field "role" Decode.string) feature.properties, roundTheLap feature.geometry ) of
        ( Ok role, Just coordinates ) ->
            Just
                { role = role
                , coordinates = coordinates
                , metres = Decode.decodeValue (Decode.field "metres" (Decode.list Decode.float)) feature.properties |> Result.toMaybe
                , frame = Decode.decodeValue frame feature.properties |> Result.toMaybe
                , direction = Decode.decodeValue directionDecoder feature.properties |> Result.toMaybe
                }

        _ ->
            Nothing


roundTheLap : Maybe GeoJson.Geometry -> Maybe (List Coordinate)
roundTheLap geometry =
    case geometry of
        Just (GeoJson.LineString positions) ->
            Just (List.map (\( lon, lat, _ ) -> { lat = lat, lon = lon }) positions)

        _ ->
            Nothing


type alias Feature =
    { role : String
    , coordinates : List Coordinate
    , metres : Maybe (List Float)
    , frame : Maybe Frame
    , direction : Maybe Direction
    }


assemble : Float -> List Feature -> Decoder Geometry
assemble lapLength features =
    case ( find "outline" features, find "pit_lane" features ) of
        ( Just outline, Just pitLane ) ->
            case ( outline.metres, outline.frame, outline.direction ) of
                ( Just metres, Just projected, Just whichWay ) ->
                    case verify lapLength metres outline.coordinates of
                        Just complaint ->
                            Decode.fail complaint

                        Nothing ->
                            Decode.succeed
                                { frame = projected
                                , direction = whichWay
                                , centreline =
                                    List.map2
                                        (\place metre -> { lat = place.lat, lon = place.lon, metres = metre })
                                        outline.coordinates
                                        metres
                                , pitLane = pitLane.coordinates
                                }

                _ ->
                    Decode.fail "the outline carries no metres, frame, or direction"

        _ ->
            Decode.fail "the geometry holds no outline or no pit lane"


find : String -> List Feature -> Maybe Feature
find role =
    List.filter (\one -> one.role == role) >> List.head


verify : Float -> List Float -> List Coordinate -> Maybe String
verify lapLength metres coordinates =
    if List.length metres /= List.length coordinates then
        Just (String.fromInt (List.length metres) ++ " metres for " ++ String.fromInt (List.length coordinates) ++ " points")

    else
        case firstDrop metres Nothing 0 of
            Just at ->
                Just ("metres go backwards at point " ++ String.fromInt at)

            Nothing ->
                case List.reverse metres of
                    last :: _ ->
                        if abs (last - lapLength) > 0.1 then
                            Just ("the outline ends at " ++ String.fromFloat last ++ " m, not the published " ++ String.fromFloat lapLength ++ " m")

                        else
                            Nothing

                    [] ->
                        Just "the outline holds no points"


firstDrop : List Float -> Maybe Float -> Int -> Maybe Int
firstDrop rest previous at =
    case rest of
        [] ->
            Nothing

        next :: after ->
            case previous of
                Just before ->
                    if next < before then
                        Just at

                    else
                        firstDrop after (Just next) (at + 1)

                Nothing ->
                    firstDrop after (Just next) (at + 1)


frame : Decoder Frame
frame =
    Decode.map3
        (\originLat originLon parallel ->
            Geodesy.frame { origin = { lat = originLat, lon = originLon }, parallel = parallel }
        )
        (Decode.field "frame" (Decode.field "origin" (Decode.field "lat" Decode.float)))
        (Decode.field "frame" (Decode.field "origin" (Decode.field "lon" Decode.float)))
        (Decode.field "frame" (Decode.field "parallel" Decode.float))


{-| Which way a car goes round the outline. Both spellings are matched and a
third is a failure rather than a silent half-turn: the word comes from the
survey's own orientation, and a file that spells it some other way has been
edited rather than surveyed.
-}
directionDecoder : Decoder Direction
directionDecoder =
    Decode.field "direction" Decode.string
        |> Decode.andThen
            (\raw ->
                case raw of
                    "clockwise" ->
                        Decode.succeed Clockwise

                    "counter_clockwise" ->
                        Decode.succeed CounterClockwise

                    other ->
                        Decode.fail ("Unknown circuit direction: " ++ other)
            )
