module Motorsport.Wec.Circuit.Geometry exposing (Geometry, LapPoint, decoder)

{-| The geometry a circuit is drawn from, as its served file holds it: the
surveyed degrees, how far round the lap each stands, and the
[`Frame`](Motorsport-Circuit-Geodesy#Frame) to project them through.

The file is written by the pipeline in `app/scripts` and served under
`/static/geometry/`, named by the word the summaries send for the circuit. The
pipeline checks the file against the circuit's authored config on the way out;
[`decoder`](#decoder) runs the same checks again on the bytes as they arrive,
because a served file is not a compiled one: it can be stale, truncated, or --
in a Tauri bundle -- the app shell itself, which is what the asset resolver
answers for a path it does not know. A geometry that fails here fails as the
round's own load failure rather than as a drawing that quietly lacks a circuit.

What the checks are _for_ is one number the file cannot vouch for itself: its
last metre must stand where the circuit's published lap length says, which is
only known from the authored side and is why the decoder is given it.

@docs Geometry, LapPoint, decoder

-}

import Json.Decode as Decode exposing (Decoder)
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
    , centreline : List LapPoint
    , pitLane : List Coordinate
    }


{-| Read a served geometry, checking it against the lap length the circuit
publishes: one metre per point, none going backwards, and the last one standing
at the published length -- the same three checks the pipeline runs on the way
out, run again on the way in.

The file's own `sectors` are not read or checked here: nothing in a drawing is
placed by them, and `check-timing-lines.mjs` is the reader that judges them.

-}
decoder : { lapLength : Float } -> Decoder Geometry
decoder { lapLength } =
    Decode.field "features" (Decode.list feature)
        |> Decode.andThen (assemble lapLength)


type alias Feature =
    { role : String
    , coordinates : List Coordinate
    , metres : Maybe (List Float)
    , frame : Maybe Frame
    }


assemble : Float -> List Feature -> Decoder Geometry
assemble lapLength features =
    case ( find "outline" features, find "pit_lane" features ) of
        ( Just outline, Just pitLane ) ->
            case ( outline.metres, outline.frame ) of
                ( Just metres, Just projected ) ->
                    case verify lapLength metres outline.coordinates of
                        Just complaint ->
                            Decode.fail complaint

                        Nothing ->
                            Decode.succeed
                                { frame = projected
                                , centreline =
                                    List.map2
                                        (\place metre -> { lat = place.lat, lon = place.lon, metres = metre })
                                        outline.coordinates
                                        metres
                                , pitLane = pitLane.coordinates
                                }

                _ ->
                    Decode.fail "the outline carries no metres or no frame"

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


feature : Decoder Feature
feature =
    Decode.map4 Feature
        (Decode.field "properties" (Decode.field "role" Decode.string))
        (Decode.field "geometry" (Decode.field "coordinates" (Decode.list coordinate)))
        (Decode.maybe (Decode.field "properties" (Decode.field "metres" (Decode.list Decode.float))))
        (Decode.maybe (Decode.field "properties" frame))


coordinate : Decoder Coordinate
coordinate =
    Decode.map2 (\lon lat -> { lat = lat, lon = lon })
        (Decode.index 0 Decode.float)
        (Decode.index 1 Decode.float)


frame : Decoder Frame
frame =
    Decode.map3
        (\originLat originLon parallel ->
            Geodesy.frame { origin = { lat = originLat, lon = originLon }, parallel = parallel }
        )
        (Decode.field "frame" (Decode.field "origin" (Decode.field "lat" Decode.float)))
        (Decode.field "frame" (Decode.field "origin" (Decode.field "lon" Decode.float)))
        (Decode.field "frame" (Decode.field "parallel" Decode.float))
