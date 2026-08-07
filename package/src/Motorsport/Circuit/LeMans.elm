module Motorsport.Circuit.LeMans exposing
    ( LeMans2025MiniSector(..)
    , all
    , compare
    , toString
    , ByMiniSector, initialize, get, map2
    , values, toList
    , layout
    )

{-| The mini-sectors of Le Mans, the counterpart of
[`Sector`](Motorsport-Sector) at the finer grain. Everything above is spelled
the way that module spells it, so a caller that knows one knows the other.

@docs LeMans2025MiniSector
@docs all
@docs compare
@docs toString


## Values held per mini sector

@docs ByMiniSector, initialize, get, map2
@docs values, toList


## The circuit itself

@docs layout

-}

import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Sector exposing (BySector)


{-| Le Mans 2025 specific mini sectors.

Written in the order a car drives them, as
[`Sector`](Motorsport-Sector#Sector) is, and that order is this module's
business: see [`all`](#all) and [`compare`](#compare).

-}
type LeMans2025MiniSector
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


{-| Every mini sector, in the order a car drives them.

Written out here rather than read off [`layout`](#layout), which is one
arrangement of them into sectors: deriving the order from the grouping would
make everything that depends on the order depend on that grouping being
complete. `LeMansTest` holds the two to each other.

-}
all : List LeMans2025MiniSector
all =
    [ SCL2
    , Z4
    , IP1
    , Z12
    , SCLC
    , A7_1
    , IP2
    , A8_1
    , SCLB
    , PORIN
    , POROUT
    , PITREF
    , SCL1
    , FORDOUT
    , FL
    ]


{-| Fifteen values, one per mini sector — [`BySector`](Motorsport-Sector#BySector)
at the finer granularity, transparent for the same reasons. Fields are in track
order.
-}
type alias ByMiniSector a =
    { scl2 : a
    , z4 : a
    , ip1 : a
    , z12 : a
    , sclc : a
    , a7_1 : a
    , ip2 : a
    , a8_1 : a
    , sclb : a
    , porin : a
    , porout : a
    , pitref : a
    , scl1 : a
    , fordout : a
    , fl : a
    }


{-| Build one value per mini sector.
-}
initialize : (LeMans2025MiniSector -> a) -> ByMiniSector a
initialize f =
    { scl2 = f SCL2
    , z4 = f Z4
    , ip1 = f IP1
    , z12 = f Z12
    , sclc = f SCLC
    , a7_1 = f A7_1
    , ip2 = f IP2
    , a8_1 = f A8_1
    , sclb = f SCLB
    , porin = f PORIN
    , porout = f POROUT
    , pitref = f PITREF
    , scl1 = f SCL1
    , fordout = f FORDOUT
    , fl = f FL
    }


{-| Read out the value for one mini sector.
-}
get : LeMans2025MiniSector -> ByMiniSector a -> a
get mini byMiniSector =
    case mini of
        SCL2 ->
            byMiniSector.scl2

        Z4 ->
            byMiniSector.z4

        IP1 ->
            byMiniSector.ip1

        Z12 ->
            byMiniSector.z12

        SCLC ->
            byMiniSector.sclc

        A7_1 ->
            byMiniSector.a7_1

        IP2 ->
            byMiniSector.ip2

        A8_1 ->
            byMiniSector.a8_1

        SCLB ->
            byMiniSector.sclb

        PORIN ->
            byMiniSector.porin

        POROUT ->
            byMiniSector.porout

        PITREF ->
            byMiniSector.pitref

        SCL1 ->
            byMiniSector.scl1

        FORDOUT ->
            byMiniSector.fordout

        FL ->
            byMiniSector.fl


{-| Combine two sets of per-mini-sector values, mini sector by mini sector.
-}
map2 : (a -> b -> c) -> ByMiniSector a -> ByMiniSector b -> ByMiniSector c
map2 f a b =
    initialize (\mini -> f (get mini a) (get mini b))


{-| The values in track order.
-}
values : ByMiniSector a -> List a
values byMiniSector =
    List.map (\mini -> get mini byMiniSector) all


{-| The values in track order, each paired with its mini sector.
-}
toList : ByMiniSector a -> List ( LeMans2025MiniSector, a )
toList byMiniSector =
    List.map (\mini -> ( mini, get mini byMiniSector )) all


{-| Le Mans 2025 layout: which mini sectors make up each sector, and which way
round the cars go. Every mini sector of [`all`](#all) appears exactly once, in
the same order.
-}
layout :
    { direction : Direction
    , sectors : BySector (List LeMans2025MiniSector)
    }
layout =
    { direction = Clockwise
    , sectors =
        { s1 = [ SCL2, Z4, IP1 ]
        , s2 = [ Z12, SCLC, A7_1, IP2 ]
        , s3 = [ A8_1, SCLB, PORIN, POROUT, PITREF, SCL1, FORDOUT, FL ]
        }
    }


{-| Convert a mini sector to its string representation. For display only --
ordering goes through [`compare`](#compare).

    toString A7_1
    --> "A7-1"

-}
toString : LeMans2025MiniSector -> String
toString mini =
    case mini of
        SCL2 ->
            "SCL2"

        Z4 ->
            "Z4"

        IP1 ->
            "IP1"

        Z12 ->
            "Z12"

        SCLC ->
            "SCLC"

        A7_1 ->
            "A7-1"

        IP2 ->
            "IP2"

        A8_1 ->
            "A8-1"

        SCLB ->
            "SCLB"

        PORIN ->
            "PORIN"

        POROUT ->
            "POROUT"

        PITREF ->
            "PITREF"

        SCL1 ->
            "SCL1"

        FORDOUT ->
            "FORDOUT"

        FL ->
            "FL"


{-| Order two mini-sectors by where they fall on the lap. The counterpart of
[`Sector.compare`](Motorsport-Sector#compare), and there for the same reason:
placing a mini-sector against the one the car is in.

    Motorsport.Circuit.LeMans.compare IP1 Z12
    --> LT

    Motorsport.Circuit.LeMans.compare FL FL
    --> EQ

-}
compare : LeMans2025MiniSector -> LeMans2025MiniSector -> Order
compare a b =
    Basics.compare (toIndex a) (toIndex b)


{-| A `case` rather than a lookup in [`all`](#all): it runs inside the per-frame
comparison that puts the field in order, and a mini sector missing from a list
would have to be given some index anyway -- silently the first -- where here the
compiler will not let one be missing.
-}
toIndex : LeMans2025MiniSector -> Int
toIndex mini =
    case mini of
        SCL2 ->
            0

        Z4 ->
            1

        IP1 ->
            2

        Z12 ->
            3

        SCLC ->
            4

        A7_1 ->
            5

        IP2 ->
            6

        A8_1 ->
            7

        SCLB ->
            8

        PORIN ->
            9

        POROUT ->
            10

        PITREF ->
            11

        SCL1 ->
            12

        FORDOUT ->
            13

        FL ->
            14
