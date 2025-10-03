module Motorsport.Circuit exposing
    ( Circuit, Layout
    , standard, leMans2025
    , hasMiniSectors
    , leMans2025SectorDefaultRatio, leMans2025MiniSectorDefalutRatio
    , Direction(..)
    )

{-|

@docs Circuit, Layout
@docs standard, leMans2025
@docs hasMiniSectors

@docs leMans2025SectorDefaultRatio, leMans2025MiniSectorDefalutRatio

-}

import List.Extra
import Motorsport.Sector exposing (MiniSector(..), Sector(..))


{-| Circuit information
-}
type alias Circuit =
    { name : String
    , direction : Direction
    , layout : Layout
    }


{-| Circuit direction
-}
type Direction
    = Clockwise
    | Counterclockwise


{-| Circuit sector layout
A list of sectors with their associated mini sectors
-}
type alias Layout =
    List ( Sector, List MiniSector )


{-| Standard 3-sector layout (no mini sectors)
-}
standard : Layout
standard =
    [ ( S1, [] ), ( S2, [] ), ( S3, [] ) ]


{-| Le Mans 2025 layout (with mini sectors)
-}
leMans2025 : Layout
leMans2025 =
    [ ( S1, [ SCL2, Z4, IP1 ] )
    , ( S2, [ Z12, SCLC, A7_1, IP2 ] )
    , ( S3, [ A8_1, SCLB, PORIN, POROUT, PITREF, SCL1, FORDOUT, FL ] )
    ]


{-| Check if a layout contains mini sectors
-}
hasMiniSectors : Layout -> Bool
hasMiniSectors layout =
    layout
        |> List.all (\( _, miniSectors ) -> not (List.isEmpty miniSectors))


{-| Get the default ratio for a specific sector in Le Mans 2025
Returns Nothing if the sector is not found
-}
leMans2025SectorDefaultRatio : Float
leMans2025SectorDefaultRatio =
    1 / 3


{-| Mini sector ratio information
Represents the default ratio of a mini sector for layout calculations
-}
type alias MiniSectorRatio =
    { mini : MiniSector
    , ratio : Float
    }


{-| Le Mans 2025 mini sector ratios
-}
leMans2025MiniSectorDefaultRatios : List MiniSectorRatio
leMans2025MiniSectorDefaultRatios =
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
leMans2025MiniSectorDefalutRatio : MiniSector -> Maybe Float
leMans2025MiniSectorDefalutRatio miniSector =
    leMans2025MiniSectorDefaultRatios
        |> List.Extra.find (\r -> r.mini == miniSector)
        |> Maybe.map .ratio
