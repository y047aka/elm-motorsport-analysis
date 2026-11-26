module Motorsport.Wec.Circuit.Map exposing (Intermediates, intermediatesDecoder, centreline, line, inOrder)

{-| A circuit map's record, as the app is served it at `static/circuit-maps/<word>.json`: the figures the map prints, kept by hand off the series' circuit map.
The upstream pipeline (`github:y047aka/circuit-maps-3d`) stretches the served geometry to the same record's centreline, so a record changed without the geometry re-laid is a geometry the decoder refuses.

@docs Intermediates, intermediatesDecoder, centreline, line, inOrder

-}

import Json.Decode as Decode exposing (Decoder)
import Length exposing (Length)
import Quantity


{-| What a map that is timed in three sectors gives the drawing: its centreline and its two intermediate lines.
-}
type alias Intermediates =
    { centreline : Length
    , intermediate1 : Length
    , intermediate2 : Length
    }


{-| Reading a record that has to give all three of [`Intermediates`](#Intermediates), in the order a car reaches them.
-}
intermediatesDecoder : Decoder Intermediates
intermediatesDecoder =
    Decode.map3 Intermediates
        centreline
        (line "intermediate1")
        (line "intermediate2")
        |> Decode.andThen (\map -> inOrder map.centreline [ map.intermediate1, map.intermediate2 ] map)


{-| The lap's length, as the map's `Centerline`.
-}
centreline : Decoder Length
centreline =
    Decode.map Length.meters (Decode.at [ "lengths", "centerline", "metres" ] Decode.float)


{-| How far from the finish line the record puts a line it names.
-}
line : String -> Decoder Length
line name =
    Decode.map Length.meters (Decode.at [ "lines", name, "metres" ] Decode.float)


{-| A record's figures, refused unless its lines stand in the order a car reaches them and all of them before the finish line closes the lap.
A drawing laid from lines out of order places every car between them wrong without failing anywhere else.
-}
inOrder : Length -> List Length -> a -> Decoder a
inOrder lap lines figures =
    let
        stops =
            Quantity.zero :: lines ++ [ lap ]
    in
    if List.all identity (List.map2 (\a b -> a |> Quantity.lessThan b) stops (List.drop 1 stops)) then
        Decode.succeed figures

    else
        Decode.fail ("the map's lines do not stand in order round its " ++ String.fromFloat (Length.inMeters lap) ++ " m lap: " ++ String.join ", " (List.map (String.fromFloat << Length.inMeters) lines))
