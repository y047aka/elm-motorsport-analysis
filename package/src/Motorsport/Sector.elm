module Motorsport.Sector exposing
    ( Sector(..)
    , all
    , compare, next, previous
    , toString
    )

{-|

@docs Sector
@docs all
@docs compare, next, previous
@docs toString

-}


{-| A sector is a segment of a racing circuit.

The three constructors are written in the order a car drives them, and that
order is the module's business: see [`compare`](#compare).

-}
type Sector
    = S1
    | S2
    | S3


{-| Every sector, in the order a car drives them. Iterate over this rather than
writing `S1`/`S2`/`S3` out by hand, so adding a sector is a compiler error
instead of a silent omission.

    all
    --> [ S1, S2, S3 ]

-}
all : List Sector
all =
    [ S1, S2, S3 ]


{-| Order sectors by how far around the lap they are — a car in `S3` is further
along than one in `S1`.

Note this says nothing about race position: further around the current lap is
usually ahead, but that is the caller's inference to make, not this function's.

    Motorsport.Sector.compare S1 S3
    --> LT

    Motorsport.Sector.compare S2 S2
    --> EQ

-}
compare : Sector -> Sector -> Order
compare a b =
    Basics.compare (toIndex a) (toIndex b)


{-| Zero-based position around the lap. Kept private: it is an implementation
detail of the ordering, not a number worth handing out.
-}
toIndex : Sector -> Int
toIndex sector =
    case sector of
        S1 ->
            0

        S2 ->
            1

        S3 ->
            2


{-| The sector a car enters next, or `Nothing` at the end of the lap — crossing
the line starts a new lap, which this module knows nothing about.

    next S1
    --> Just S2

    next S3
    --> Nothing

-}
next : Sector -> Maybe Sector
next sector =
    case sector of
        S1 ->
            Just S2

        S2 ->
            Just S3

        S3 ->
            Nothing


{-| The sector a car just left, or `Nothing` at the start of the lap.

    previous S3
    --> Just S2

    previous S1
    --> Nothing

-}
previous : Sector -> Maybe Sector
previous sector =
    case sector of
        S1 ->
            Nothing

        S2 ->
            Just S1

        S3 ->
            Just S2


{-| Convert a sector to its string representation. For display only — ordering
goes through [`compare`](#compare).

    toString S1
    --> "S1"

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
