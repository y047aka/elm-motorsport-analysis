module Motorsport.Wec.Circuit.LeMans.Layout exposing (Layout, TimingLines, layout)

{-| The Circuit de la Sarthe as a map draws it: the lap, the pit lane beside
it, and where round the lap the lines it is timed at stand.

@docs Layout, TimingLines, layout

-}

import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Sector as Sector exposing (BySector, Sector(..))
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector, LeMans2025MiniSector(..))
import Motorsport.Wec.Circuit.LeMans.Geometry as Geometry


type alias Layout =
    { shape : Shape
    , pitLane : List Point
    , timingLines : TimingLines
    }


{-| How far round the lap, in metres, each stretch of it ends: where the line it
is timed to stands. A mini-sector ends at the line it is named for.

`Nothing` is a line the season's circuit map gives no distance for.

-}
type alias TimingLines =
    { sectors : BySector Float
    , miniSectors : ByMiniSector (Maybe Float)
    }


{-| The circuit as a season's race was timed on it. A season after the last one
here is read as that one.
-}
layout : Int -> Layout
layout season =
    { shape = shape
    , pitLane = Geometry.pitLane
    , timingLines = timingLines season
    }


shape : Shape
shape =
    Shape.fromMarks Geometry.centreline


{-| The "Approximate Distances" of Al Kamel's circuit map for each race, which
name six of the lines and not the rest. 2024's map gives Ford In apart from
Safety Car Line 1, and does not place the latter.
-}
timingLines : Int -> TimingLines
timingLines season =
    if season <= 2024 then
        published
            { intermediate1 = 1899.09
            , intermediate2 = 7670.63
            , porscheIn = 11475.05
            , porscheOut = 12504.4
            , safetyCarLine1 = Nothing
            , fordOut = 13469.78
            }

    else if season == 2025 then
        published
            { intermediate1 = 1899.1
            , intermediate2 = 7670.63
            , porscheIn = 11475.05
            , porscheOut = 12504.4
            , safetyCarLine1 = Just 13251.0
            , fordOut = 13469.78
            }

    else
        published
            { intermediate1 = 1900.7
            , intermediate2 = 7672.13
            , porscheIn = 11475.77
            , porscheOut = 12507.09
            , safetyCarLine1 = Just 13246.35
            , fordOut = 13470.88
            }


published :
    { intermediate1 : Float
    , intermediate2 : Float
    , porscheIn : Float
    , porscheOut : Float
    , safetyCarLine1 : Maybe Float
    , fordOut : Float
    }
    -> TimingLines
published lines =
    let
        finishLine =
            Shape.length shape
    in
    { sectors =
        Sector.initialize
            (\sector ->
                case sector of
                    S1 ->
                        lines.intermediate1

                    S2 ->
                        lines.intermediate2

                    S3 ->
                        finishLine
            )
    , miniSectors =
        LeMans.initialize
            (\mini ->
                case mini of
                    SCL2 ->
                        Nothing

                    Z4 ->
                        Nothing

                    IP1 ->
                        Just lines.intermediate1

                    Z12 ->
                        Nothing

                    SCLC ->
                        Nothing

                    A7_1 ->
                        Nothing

                    IP2 ->
                        Just lines.intermediate2

                    A8_1 ->
                        Nothing

                    SCLB ->
                        Nothing

                    PORIN ->
                        Just lines.porscheIn

                    POROUT ->
                        Just lines.porscheOut

                    PITREF ->
                        Nothing

                    SCL1 ->
                        lines.safetyCarLine1

                    FORDOUT ->
                        Just lines.fordOut

                    FL ->
                        Just finishLine
            )
    }
