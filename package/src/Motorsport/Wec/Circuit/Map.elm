module Motorsport.Wec.Circuit.Map exposing (Intermediates, intermediatesDecoder, centreline, line)

{-| A circuit map's record, as the app is served it at `static/circuit-maps/<word>.json`: the figures the map prints, kept by hand off the series' circuit map.
The circuits project reads the same file for the lap it stretches a survey to and the stretches its geometry carries, so the drawing and the geometry are laid from one set of figures.

@docs Intermediates, intermediatesDecoder, centreline, line

-}

import Json.Decode as Decode exposing (Decoder)


{-| What a map that is timed in three sectors gives the drawing: its centreline and its two intermediate lines.
-}
type alias Intermediates =
    { centreline : Float
    , intermediate1 : Float
    , intermediate2 : Float
    }


{-| Reading a record that has to give all three of [`Intermediates`](#Intermediates).
-}
intermediatesDecoder : Decoder Intermediates
intermediatesDecoder =
    Decode.map3 Intermediates
        centreline
        (line "intermediate1")
        (line "intermediate2")


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
