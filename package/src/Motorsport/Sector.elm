module Motorsport.Sector exposing
    ( Sector(..)
    , toString
    )

{-|

@docs Sector
@docs toString

-}


{-| A sector is a segment of a racing circuit
-}
type Sector
    = S1
    | S2
    | S3


{-| Convert a sector to its string representation
-}
toString : Sector -> String
toString sector =
    case sector of
        S1 ->
            "S1"

        S2 ->
            "S2"

        S3 ->
            "S3"
