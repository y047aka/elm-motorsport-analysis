module Motorsport.Widget.BestLapTimes exposing (view)

import Css exposing (alignItems, backgroundColor, bold, borderRadius, borderTop3, center, color, displayFlex, fontSize, fontWeight, height, hsl, nthChild, padding, padding2, property, px, solid, textAlign, width, zero)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Class exposing (Class)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.RaceControl.ViewModel exposing (ViewModel)
import Motorsport.Widget as Widget


type alias CarLapData =
    { class : Class
    , carNumber : String
    , bestTime : Duration
    , sector1 : Duration
    , sector2 : Duration
    , sector3 : Duration
    , s1_best : Duration
    , s2_best : Duration
    , s3_best : Duration
    }


type alias ClassData =
    { class : Class
    , cars : List CarLapData
    }


view : Analysis -> ViewModel -> Html msg
view analysis viewModel =
    let
        classBestTimes =
            processClassBestTimes viewModel
    in
    Widget.container "Best Lap Times"
        (classListView analysis classBestTimes)


processClassBestTimes : ViewModel -> List ClassData
processClassBestTimes viewModel =
    viewModel.itemsByClass
        |> List.map
            (\( class, cars ) ->
                { class = class
                , cars =
                    cars
                        |> List.sortBy (.lastLap >> Maybe.map .best >> Maybe.withDefault 999999)
                        |> List.take 3
                        |> List.map
                            (\car ->
                                car.lastLap
                                    |> Maybe.map
                                        (\lap ->
                                            { class = car.metaData.class
                                            , carNumber = car.metaData.carNumber
                                            , bestTime = lap.best
                                            , sector1 = lap.sector_1
                                            , sector2 = lap.sector_2
                                            , sector3 = lap.sector_3
                                            , s1_best = lap.s1_best
                                            , s2_best = lap.s2_best
                                            , s3_best = lap.s3_best
                                            }
                                        )
                            )
                        |> List.filterMap identity
                }
            )


classListView : Analysis -> List ClassData -> Html msg
classListView analysis classBestTimes =
    div
        [ css
            [ property "display" "flex"
            , property "flex-direction" "column"
            ]
        ]
        (List.map (classItemView analysis) classBestTimes)


classItemView : Analysis -> ClassData -> Html msg
classItemView analysis { class, cars } =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "8px"
            , padding2 (px 10) zero
            , fontSize (px 12)
            , nthChild "n+2"
                [ borderTop3 (px 1) solid (hsl 0 0 0.4) ]
            ]
        ]
        [ Widget.classHeader class []
        , carListView analysis cars
        ]


carListView : Analysis -> List CarLapData -> Html msg
carListView analysis cars =
    div
        [ css
            [ property "display" "flex"
            , property "flex-direction" "column"
            , property "gap" "2px"
            ]
        ]
        (List.indexedMap (carItemView analysis) cars)


carItemView : Analysis -> Int -> CarLapData -> Html msg
carItemView analysis carIndex carLapData =
    let
        position =
            carIndex + 1

        { carNumber, bestTime } =
            carLapData
    in
    div
        [ css
            [ displayFlex
            , alignItems center
            , property "column-gap" "4px"
            , padding (px 5)
            , borderRadius (px 4)
            , backgroundColor (hsl 0 0 0.15)
            , fontSize (px 12)
            ]
        ]
        [ div
            [ css
                [ width (px 16)
                , height (px 16)
                , borderRadius (px 8)
                , backgroundColor (hsl 0 0 0.3)
                , color (hsl 0 0 0.9)
                , fontSize (px 10)
                , fontWeight bold
                , property "display" "grid"
                , property "place-items" "center"
                ]
            ]
            [ text (String.fromInt position) ]
        , div
            [ css
                [ fontSize (px 11)
                , fontWeight (Css.int 500)
                , color (hsl 0 0 0.8)
                , width (px 35)
                ]
            ]
            [ text ("#" ++ carNumber) ]
        , div
            [ css
                [ fontSize (px 11)
                , fontWeight (Css.int 600)
                , color (hsl 0 0 0.9)
                , width (px 65)
                ]
            ]
            [ text (Duration.toString bestTime) ]
        , sectorTimesView analysis carLapData
        ]


sectorTimesView : Analysis -> CarLapData -> Html msg
sectorTimesView analysis { sector1, sector2, sector3, s1_best, s2_best, s3_best } =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "repeat(3, 1fr)"
            , property "column-gap" "2px"
            ]
        ]
        [ sectorCell sector1 s1_best analysis.sector_1_fastest
        , sectorCell sector2 s2_best analysis.sector_2_fastest
        , sectorCell sector3 s3_best analysis.sector_3_fastest
        ]


sectorCell : Duration -> Duration -> Duration -> Html msg
sectorCell sectorTime personalBest fastest =
    div
        [ css
            [ padding (px 4)
            , borderRadius (px 3)
            , textAlign center
            , fontSize (px 10)
            , fontWeight bold
            , backgroundColor (sectorCellBackgroundColor sectorTime personalBest fastest)
            , color (hsl 0 0 1)
            ]
        ]
        [ text (Duration.toString sectorTime) ]


sectorCellBackgroundColor : Duration -> Duration -> Duration -> Css.Color
sectorCellBackgroundColor sectorTime personalBest fastest =
    if sectorTime <= fastest then
        hsl 280 0.7 0.5

    else if sectorTime <= personalBest then
        hsl 120 0.7 0.4

    else
        hsl 0 0 0.4
