module Motorsport.Sector exposing
    ( Sector(..)
    , all
    , compare, next, previous
    , toString
    , BySector, initialize, get, map2
    , values, toList
    )

{-|

@docs Sector
@docs all
@docs compare, next, previous
@docs toString


## Values held per sector

@docs BySector, initialize, get, map2
@docs values, toList

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



-- VALUES HELD PER SECTOR


{-| Three values, one per sector — a sector time, a progress percentage, a
fastest time to compare against.

Source records spell this out flat (`sector_1`, `sector_2`, `sector_3`), which
leaves callers writing the same three-way `case` to pick one out. Convert once
at the boundary and the picking becomes [`get`](#get).

-}
type alias BySector a =
    { s1 : a
    , s2 : a
    , s3 : a
    }


{-| Build one value per sector.

    initialize toString
    --> { s1 = "S1", s2 = "S2", s3 = "S3" }

-}
initialize : (Sector -> a) -> BySector a
initialize f =
    { s1 = f S1
    , s2 = f S2
    , s3 = f S3
    }


{-| Read out the value for one sector.

    get S2 (initialize toString)
    --> "S2"

-}
get : Sector -> BySector a -> a
get sector bySector =
    case sector of
        S1 ->
            bySector.s1

        S2 ->
            bySector.s2

        S3 ->
            bySector.s3


{-| Combine two sets of per-sector values sector by sector — a time with the
fastest time to rate it against, a progress with its rating.
-}
map2 : (a -> b -> c) -> BySector a -> BySector b -> BySector c
map2 f a b =
    { s1 = f a.s1 b.s1
    , s2 = f a.s2 b.s2
    , s3 = f a.s3 b.s3
    }


{-| The three values in sector order — for rendering a row or a column of
cells, where the sector itself is implied by position.

    values (initialize toString)
    --> [ "S1", "S2", "S3" ]

-}
values : BySector a -> List a
values bySector =
    [ bySector.s1, bySector.s2, bySector.s3 ]


{-| The three values in sector order, each paired with its sector.

    toList (initialize toString)
    --> [ ( S1, "S1" ), ( S2, "S2" ), ( S3, "S3" ) ]

-}
toList : BySector a -> List ( Sector, a )
toList bySector =
    [ ( S1, bySector.s1 ), ( S2, bySector.s2 ), ( S3, bySector.s3 ) ]
