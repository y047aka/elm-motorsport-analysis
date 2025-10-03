module Motorsport.Sector exposing
    ( Sector(..)
    , MiniSector(..)
    , toString
    )

{-|

@docs Sector
@docs MiniSector
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


{-| A mini sector is a subsegment within a sector (used in some circuits like Le Mans)
-}
type MiniSector
    = SCL2
    | Z4
    | IP1
    | Z12
    | SCLC
    | A7_1
    | IP2
    | A8_1
    | SCLB
    | PORIN
    | POROUT
    | PITREF
    | SCL1
    | FORDOUT
    | FL
