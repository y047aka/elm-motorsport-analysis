module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig
    , MiniSectorData(..)
    , buildConfig
    , computeProgress, calcSectorBoundaries
    )

{-|

@docs TrackConfig
@docs MiniSectorData
@docs buildConfig
@docs computeProgress, calcSectorBoundaries

-}

import List.Extra
import Motorsport.Circuit as Circuit exposing (Layout)
import Motorsport.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap.Performance exposing (LeMans2025MiniSectorFastest)
import Motorsport.Sector exposing (Sector(..))
import Motorsport.ViewModel.Standings exposing (MiniSectorProgress, SectorProgress, Entry)


type alias TrackConfig =
    List SectorConfig


type alias SectorConfig =
    { sector : Sector
    , start : Float
    , share : Float
    , miniSectorData : MiniSectorData
    }


type MiniSectorData
    = WithMiniSectors (List MiniSectorShare)
    | NoMiniSectors


type alias MiniSectorShare =
    { mini : LeMans2025MiniSector
    , start : Float
    , share : Float
    }


buildConfig :
    Layout LeMans2025MiniSector
    ->
        { a
            | fastestSector_1 : Duration
            , fastestSector_2 : Duration
            , fastestSector_3 : Duration
            , fastestMiniSectors : LeMans2025MiniSectorFastest
        }
    -> TrackConfig
buildConfig layout bestTimes =
    let
        isLeMans2025 =
            Circuit.hasMiniSectors layout

        totalTime =
            if isLeMans2025 then
                LeMans.miniSectorOrder
                    |> List.map (\mini -> LeMans.miniSectorAccessor mini bestTimes.fastestMiniSectors)
                    |> List.sum
                    |> toFloat

            else
                toFloat (bestTimes.fastestSector_1 + bestTimes.fastestSector_2 + bestTimes.fastestSector_3)

        miniRatio miniSector =
            let
                value =
                    LeMans.miniSectorAccessor miniSector bestTimes.fastestMiniSectors
                        |> toFloat

                defaultRatio =
                    LeMans.miniSectorDefaultRatio miniSector
                        |> Maybe.withDefault 0
            in
            if totalTime == 0 then
                defaultRatio

            else
                value / totalTime

        shares =
            computeSectorShares layout bestTimes totalTime miniRatio
    in
    [ { sector = S1
      , start = 0
      , share = shares.s1
      , miniSectorData = buildMiniSectors layout.s1 0 miniRatio
      }
    , { sector = S2
      , start = shares.s1
      , share = shares.s2
      , miniSectorData = buildMiniSectors layout.s2 shares.s1 miniRatio
      }
    , { sector = S3
      , start = shares.s1 + shares.s2
      , share = shares.s3
      , miniSectorData = buildMiniSectors layout.s3 (shares.s1 + shares.s2) miniRatio
      }
    ]


computeSectorShares :
    Layout LeMans2025MiniSector
    -> { a | fastestSector_1 : Duration, fastestSector_2 : Duration, fastestSector_3 : Duration }
    -> Float
    -> (LeMans2025MiniSector -> Float)
    -> { s1 : Float, s2 : Float, s3 : Float }
computeSectorShares layout bestTimes totalTime miniRatio =
    let
        sectorShare fastestTime miniSectors =
            case miniSectors of
                [] ->
                    let
                        value =
                            toFloat fastestTime
                    in
                    if totalTime == 0 then
                        Circuit.sectorDefaultRatio

                    else
                        value / totalTime

                _ ->
                    miniSectors
                        |> List.map miniRatio
                        |> List.sum
    in
    { s1 = sectorShare bestTimes.fastestSector_1 layout.s1
    , s2 = sectorShare bestTimes.fastestSector_2 layout.s2
    , s3 = sectorShare bestTimes.fastestSector_3 layout.s3
    }


buildMiniSectors : List LeMans2025MiniSector -> Float -> (LeMans2025MiniSector -> Float) -> MiniSectorData
buildMiniSectors miniSectors sectorStart miniRatio =
    case miniSectors of
        [] ->
            NoMiniSectors

        _ ->
            miniSectors
                |> List.foldl
                    (\mini ( acc, current ) ->
                        let
                            ratio =
                                miniRatio mini
                        in
                        ( { mini = mini, share = ratio, start = current } :: acc
                        , current + ratio
                        )
                    )
                    ( [], sectorStart )
                |> Tuple.first
                |> List.reverse
                |> WithMiniSectors


computeProgress : TrackConfig -> Entry -> Float
computeProgress config car =
    if car.currentLapProgress > 0 then
        car.currentLapProgress

    else
        case ( car.sector, car.miniSector ) of
            ( _, Just miniSectorProgress ) ->
                progressFromMiniSector config miniSectorProgress

            ( Just sectorProgress, Nothing ) ->
                progressFromSector config sectorProgress

            ( Nothing, Nothing ) ->
                0


progressFromSector : List SectorConfig -> SectorProgress -> Float
progressFromSector sectors { sector, progress } =
    sectors
        |> List.Extra.find (\sectorConfig -> sectorConfig.sector == sector)
        |> Maybe.map (\{ start, share } -> start + (progress / 100) * share)
        |> Maybe.withDefault 0


progressFromMiniSector : TrackConfig -> MiniSectorProgress -> Float
progressFromMiniSector config { miniSector, progress } =
    case findMiniSectorShare config miniSector of
        Just { start, share } ->
            start + progress * share

        Nothing ->
            0


findMiniSectorShare : List SectorConfig -> LeMans2025MiniSector -> Maybe MiniSectorShare
findMiniSectorShare sectors targetMini =
    sectors
        |> List.concatMap
            (\sector ->
                case sector.miniSectorData of
                    NoMiniSectors ->
                        []

                    WithMiniSectors minis ->
                        minis
            )
        |> List.Extra.find (\{ mini } -> mini == targetMini)


calcSectorBoundaries : List SectorConfig -> List Float
calcSectorBoundaries sectors =
    let
        ( _, boundariesRev ) =
            sectors
                |> List.foldl accumulateBoundaries ( 0, [] )
    in
    boundariesRev
        |> List.filter (\boundary -> boundary > 0 && boundary < 1)
        |> List.reverse


accumulateBoundaries : SectorConfig -> ( Float, List Float ) -> ( Float, List Float )
accumulateBoundaries sectorConfig ( currentStart, acc ) =
    case sectorConfig.miniSectorData of
        NoMiniSectors ->
            let
                end =
                    currentStart + sectorConfig.share

                updatedAcc =
                    if sectorConfig.share <= 0 then
                        acc

                    else
                        end :: acc
            in
            ( end, updatedAcc )

        WithMiniSectors minis ->
            minis
                |> List.foldl
                    (\miniShare ( runningTotal, accInner ) ->
                        let
                            nextTotal =
                                runningTotal + miniShare.share

                            updatedAcc =
                                if miniShare.share <= 0 then
                                    accInner

                                else
                                    nextTotal :: accInner
                        in
                        ( nextTotal, updatedAcc )
                    )
                    ( currentStart, acc )
