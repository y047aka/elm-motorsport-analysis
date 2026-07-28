module Motorsport.Circuit.LeMans exposing
    ( LeMans2025MiniSector(..)
    , ByMiniSector, initialize, get, map2, values
    , calculateMiniSectorProgress
    , layout, miniSectorDefaultRatio, miniSectorOrder, miniSectorToString
    )

{-|

@docs LeMans2025MiniSector


## Values held per mini sector

@docs ByMiniSector, initialize, get, map2, values

@docs calculateMiniSectorProgress

-}

import List.Extra
import Motorsport.Direction exposing (Direction(..))


{-| Le Mans 2025 specific mini sectors
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


{-| Fifteen values, one per mini sector — the counterpart of
[`BySector`](Motorsport-Sector#BySector) at the finer granularity, and a
transparent record for the same reasons.

Fields are in track order, so a record literal and
[`miniSectorOrder`](#miniSectorOrder) read the same way round.

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
    List.map (\mini -> get mini byMiniSector) miniSectorOrder


{-| Le Mans 2025 layout (sectors with their mini sectors)
-}
layout :
    { s1 : List LeMans2025MiniSector
    , s2 : List LeMans2025MiniSector
    , s3 : List LeMans2025MiniSector
    , direction : Direction
    }
layout =
    { s1 = [ SCL2, Z4, IP1 ]
    , s2 = [ Z12, SCLC, A7_1, IP2 ]
    , s3 = [ A8_1, SCLB, PORIN, POROUT, PITREF, SCL1, FORDOUT, FL ]
    , direction = Clockwise
    }


{-| Ordered list of all mini sectors in track order
-}
miniSectorOrder : List LeMans2025MiniSector
miniSectorOrder =
    layout.s1 ++ layout.s2 ++ layout.s3


{-| Convert a mini sector to its string representation
-}
miniSectorToString : LeMans2025MiniSector -> String
miniSectorToString mini =
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


{-| Mini sector ratio information
Represents the default ratio of a mini sector for layout calculations
-}
type alias MiniSectorRatio =
    { mini : LeMans2025MiniSector
    , ratio : Float
    }


{-| Le Mans 2025 mini sector ratios
-}
miniSectorDefaultRatios : List MiniSectorRatio
miniSectorDefaultRatios =
    let
        weights =
            [ ( SCL2, 7.5 )
            , ( Z4, 7.5 )
            , ( IP1, 12 )
            , ( Z12, 24 )
            , ( SCLC, 3 )
            , ( A7_1, 15 )
            , ( IP2, 13 )
            , ( A8_1, 5.5 )
            , ( SCLB, 26 )
            , ( PORIN, 12.5 )
            , ( POROUT, 11 )
            , ( PITREF, 6 )
            , ( SCL1, 2 )
            , ( FORDOUT, 3 )
            , ( FL, 2 )
            ]

        total =
            weights |> List.map Tuple.second |> List.sum
    in
    weights
        |> List.map (\( mini, weight ) -> { mini = mini, ratio = weight / total })


{-| Get the default ratio for a specific mini sector in Le Mans 2025
Returns Nothing if the mini sector is not found
-}
miniSectorDefaultRatio : LeMans2025MiniSector -> Maybe Float
miniSectorDefaultRatio miniSector =
    miniSectorDefaultRatios
        |> List.Extra.find (\r -> r.mini == miniSector)
        |> Maybe.map .ratio


calculateMiniSectorProgress :
    Maybe { miniSector : LeMans2025MiniSector, progress : Float }
    ->
        { scl2 : Float
        , z4 : Float
        , ip1 : Float
        , z12 : Float
        , sclc : Float
        , a7_1 : Float
        , ip2 : Float
        , a8_1 : Float
        , sclb : Float
        , porin : Float
        , porout : Float
        , pitref : Float
        , scl1 : Float
        , fordout : Float
        , fl : Float
        }
calculateMiniSectorProgress maybeCurrentMiniSector =
    case maybeCurrentMiniSector of
        Nothing ->
            { scl2 = 0, z4 = 0, ip1 = 0, z12 = 0, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just { miniSector, progress } ->
            case miniSector of
                SCL2 ->
                    { scl2 = progress, z4 = 0, ip1 = 0, z12 = 0, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                Z4 ->
                    { scl2 = 1, z4 = progress, ip1 = 0, z12 = 0, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                IP1 ->
                    { scl2 = 1, z4 = 1, ip1 = progress, z12 = 0, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                Z12 ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = progress, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                SCLC ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = progress, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                A7_1 ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = progress, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                IP2 ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = progress, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                A8_1 ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = progress, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                SCLB ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = progress, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                PORIN ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = progress, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                POROUT ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = progress, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

                PITREF ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = 1, pitref = progress, scl1 = 0, fordout = 0, fl = 0 }

                SCL1 ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = 1, pitref = 1, scl1 = progress, fordout = 0, fl = 0 }

                FORDOUT ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = 1, pitref = 1, scl1 = 1, fordout = progress, fl = 0 }

                FL ->
                    { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = 1, pitref = 1, scl1 = 1, fordout = 1, fl = progress }
