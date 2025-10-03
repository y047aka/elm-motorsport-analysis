module Motorsport.Circuit.LeMans exposing
    ( LeMans2025MiniSector(..)
    , layout, miniSectorDefaultRatio, miniSectorOrder
    )

{-|

@docs LeMans2025MiniSector

-}

import List.Extra
import Motorsport.Sector exposing (Sector(..))


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
layout : List ( Sector, List LeMans2025MiniSector )
layout =
    [ ( S1, [ SCL2, Z4, IP1 ] )
    , ( S2, [ Z12, SCLC, A7_1, IP2 ] )
    , ( S3, [ A8_1, SCLB, PORIN, POROUT, PITREF, SCL1, FORDOUT, FL ] )
    ]


{-| Ordered list of all mini sectors in track order
-}
miniSectorOrder : List LeMans2025MiniSector
miniSectorOrder =
    layout
        |> List.concatMap (\( _, minis ) -> minis)


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
