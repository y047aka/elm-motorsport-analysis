module Motorsport.Wec.Circuit.Map exposing (Intermediates, intermediatesDecoder, centreline, line, inOrder)

{-| A circuit map's record, as the app is served it at `static/circuit-maps/<word>.json`: the figures the map prints, kept by hand off the series' circuit map.
The circuits project stretches the served geometry to the same record's centreline, so a record changed without the geometry re-laid (`circuits/README.md`) is a geometry the decoder refuses.

@docs Intermediates, intermediatesDecoder, centreline, line, inOrder

-}

import Json.Decode as Decode exposing (Decoder)


{-| What a map that is timed in three sectors gives the drawing: its centreline and its two intermediate lines.
-}
type alias Intermediates =
    { centreline : Float
    , intermediate1 : Float
    , intermediate2 : Float
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
centreline : Decoder Float
centreline =
    Decode.at [ "lengths", "centerline", "metres" ] Decode.float


{-| How far from the finish line the record puts a line it names.
-}
line : String -> Decoder Float
line name =
    Decode.at [ "lines", name, "metres" ] Decode.float


{-| A record's figures, refused unless its lines stand in the order a car reaches them and all of them before the finish line closes the lap.
A drawing laid from lines out of order places every car between them wrong without failing anywhere else.
-}
inOrder : Float -> List Float -> a -> Decoder a
inOrder lap lines figures =
    let
        stops =
            0 :: lines ++ [ lap ]
    in
    if List.all identity (List.map2 (<) stops (List.drop 1 stops)) then
        Decode.succeed figures

    else
        Decode.fail ("the map's lines do not stand in order round its " ++ String.fromFloat lap ++ " m lap: " ++ String.join ", " (List.map String.fromFloat lines))
