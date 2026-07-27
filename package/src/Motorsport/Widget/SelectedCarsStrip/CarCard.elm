module Motorsport.Widget.SelectedCarsStrip.CarCard exposing (view)

{-| A single car card for SelectedCarsStrip: a header row of position, gap, and
status, above the driver name, sector performance, and rival gap sparkline.

@docs view

-}

import Css exposing (before, num, opacity, property, qt)
import Html.Styled exposing (Html, div, text)
import Html.Styled.Attributes exposing (class, css)
import Motorsport.Car exposing (Status(..))
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.ViewModel.LapHistory exposing (LapHistory)
import Motorsport.ViewModel.Standings exposing (Entry)
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.SectorAndLaps as SectorAndLaps
import Motorsport.Widget.SelectedCarsStrip.RivalGapSparkline as RivalGapSparkline


{-| `allCars` is the full overall standings, not just the visible window —
the sparkline searches it for the class rivals ahead of and behind the car.
-}
view : LapHistory -> List Entry -> Entry -> Html msg
view lapHistory allCars item =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "4px"
            ]
        ]
        [ div
            [ css
                [ property "padding-inline" "8px"
                , property "display" "grid"
                , property "grid-template-columns" "auto 1fr auto"
                , property "column-gap" "16px"
                ]
            ]
            [ positionLabel item
            , gapsRow item
            , statusBadge item.status
            ]
        , div [ class "card bg-base-200" ]
            [ div
                [ class "card-body p-3"
                , css
                    [ property "display" "grid"
                    , property "row-gap" "8px"
                    ]
                ]
                [ cardHeader item
                , SectorAndLaps.view item
                , RivalGapSparkline.view lapHistory allCars item
                ]
            ]
        ]


cardHeader : Entry -> Html msg
cardHeader item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr"
            , property "align-items" "center"
            , property "column-gap" "8px"
            ]
        ]
        [ CarNumberBadge.view item
        , div
            [ css
                [ property "font-size" "12px"
                , property "white-space" "nowrap"
                , property "overflow" "hidden"
                , property "text-overflow" "ellipsis"
                ]
            ]
            [ text (item.currentDriver |> Maybe.withDefault Driver.unknown |> Driver.toFullName) ]
        ]


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            div
                [ css
                    [ property "display" "grid"
                    , property "place-items" "center"
                    , property "width" "16px"
                    , property "height" "16px"
                    , property "border-radius" "9999px"
                    , property "border" "1px solid hsl(0 0% 100% / 0.6)"
                    , property "font-size" "9px"
                    , property "font-weight" "700"
                    , property "line-height" "1"
                    ]
                ]
                [ text "P" ]

        Retired ->
            div
                [ css
                    [ property "padding" "1px 4px"
                    , property "border-radius" "3px"
                    , property "background-color" "hsl(0 70% 45%)"
                    , property "font-size" "9px"
                    , property "font-weight" "700"
                    , property "letter-spacing" "0.05em"
                    ]
                ]
                [ text "RET" ]

        _ ->
            text ""


positionLabel : Entry -> Html msg
positionLabel item =
    div
        [ css
            [ property "display" "flex"
            , property "align-items" "center"
            , property "column-gap" "4px"
            , property "font-size" "10px"
            , before
                [ property "display" "block"
                , property "content" (qt "")
                , property "width" "0.2em"
                , property "height" "1em"
                , property "border-radius" "2px"
                , property "background-color" item.classColor
                ]
            ]
        ]
        [ text ("P" ++ String.fromInt item.position) ]


gapsRow : Entry -> Html msg
gapsRow item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr"
            , property "align-items" "baseline"
            , property "font-size" "10px"
            , opacity (num 0.75)
            ]
        ]
        [ gapCell "Interval" item.intervalToAhead ]


gapCell : String -> Gap -> Html msg
gapCell label gap =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr"
            , property "align-items" "baseline"
            , property "column-gap" "4px"
            , property "font-variant-numeric" "tabular-nums"
            ]
        ]
        [ div [ css [ opacity (num 0.7) ] ]
            [ text label ]
        , div
            [ css [ property "text-align" "right" ] ]
            [ text (Gap.toString gap) ]
        ]
