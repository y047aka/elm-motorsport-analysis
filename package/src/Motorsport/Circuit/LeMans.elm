module Motorsport.Circuit.LeMans exposing
    ( LeMans2025MiniSector(..)
    , miniSectorAccessor
    , calculateMiniSectorProgress
    , layout, miniSectorDefaultRatio, miniSectorOrder
    , miniSectorToString
    )

{-|

@docs LeMans2025MiniSector

@docs miniSectorAccessor
@docs calculateMiniSectorProgress

-}

import List.Extra
import Motorsport.Direction exposing (Direction(..))
import Motorsport.Duration exposing (Duration)


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


{-| Get accessor function for a specific mini sector
This is useful for extracting fastest times from analysis records
Takes a record with Duration fields named after each mini sector
-}
miniSectorAccessor :
    LeMans2025MiniSector
    ->
        ({ scl2 : Duration
         , z4 : Duration
         , ip1 : Duration
         , z12 : Duration
         , sclc : Duration
         , a7_1 : Duration
         , ip2 : Duration
         , a8_1 : Duration
         , sclb : Duration
         , porin : Duration
         , porout : Duration
         , pitref : Duration
         , scl1 : Duration
         , fordout : Duration
         , fl : Duration
         }
         -> Duration
        )
miniSectorAccessor mini =
    case mini of
        SCL2 ->
            .scl2

        Z4 ->
            .z4

        IP1 ->
            .ip1

        Z12 ->
            .z12

        SCLC ->
            .sclc

        A7_1 ->
            .a7_1

        IP2 ->
            .ip2

        A8_1 ->
            .a8_1

        SCLB ->
            .sclb

        PORIN ->
            .porin

        POROUT ->
            .porout

        PITREF ->
            .pitref

        SCL1 ->
            .scl1

        FORDOUT ->
            .fordout

        FL ->
            .fl


{-| Calculate progress values for all mini sectors based on current mini sector and progress
Returns a record with progress (0 to 1) for each mini sector
-}
calculateMiniSectorProgress :
    Maybe ( LeMans2025MiniSector, Float )
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
        Just ( SCL2, progress ) ->
            { scl2 = progress, z4 = 0, ip1 = 0, z12 = 0, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( Z4, progress ) ->
            { scl2 = 1, z4 = progress, ip1 = 0, z12 = 0, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( IP1, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = progress, z12 = 0, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( Z12, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = progress, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( SCLC, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = progress, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( A7_1, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = progress, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( IP2, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = progress, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( A8_1, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = progress, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( SCLB, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = progress, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( PORIN, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = progress, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( POROUT, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = progress, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }

        Just ( PITREF, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = 1, pitref = progress, scl1 = 0, fordout = 0, fl = 0 }

        Just ( SCL1, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = 1, pitref = 1, scl1 = progress, fordout = 0, fl = 0 }

        Just ( FORDOUT, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = 1, pitref = 1, scl1 = 1, fordout = progress, fl = 0 }

        Just ( FL, progress ) ->
            { scl2 = 1, z4 = 1, ip1 = 1, z12 = 1, sclc = 1, a7_1 = 1, ip2 = 1, a8_1 = 1, sclb = 1, porin = 1, porout = 1, pitref = 1, scl1 = 1, fordout = 1, fl = progress }

        Nothing ->
            { scl2 = 0, z4 = 0, ip1 = 0, z12 = 0, sclc = 0, a7_1 = 0, ip2 = 0, a8_1 = 0, sclb = 0, porin = 0, porout = 0, pitref = 0, scl1 = 0, fordout = 0, fl = 0 }
