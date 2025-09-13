module Motorsport.Widget.LiveStandings exposing (view)

import Css exposing (backgroundColor, borderRadius, center, color, fontSize, fontWeight, hsl, padding, property, px, textAlign)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import Motorsport.Class as Class
import Motorsport.Gap as Gap
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget
import SortedList


view : Int -> ViewModel -> Html msg
view season viewModel =
    Widget.container ""
        (div []
            (viewModel.items
                |> SortedList.toList
                |> List.map (carRow season)
            )
        )


carRow : Int -> ViewModelItem -> Html msg
carRow season item =
    div
        [ css
            [ property "padding-block" "8px"
            , property "display" "grid"
            , property "grid-template-columns" "20px 35px 1fr 80px"
            , property "align-items" "center"
            , property "column-gap" "8px"
            , property "border-bottom" "1px solid hsl(0 0% 100% / 0.1)"
            , property "font-size" "12px"
            ]
        ]
        [ div [ css [ textAlign center ] ] [ text (String.fromInt item.position) ]
        , div
            [ css
                [ textAlign center
                , fontWeight Css.bold
                , backgroundColor (Class.toHexColor season item.metadata.class)
                , color (hsl 0 0 1)
                , borderRadius (px 4)
                , padding (px 4)
                , fontSize (px 11)
                ]
            ]
            [ text item.metadata.carNumber ]
        , div []
            [ div [ css [ fontWeight Css.bold ] ] [ text item.metadata.team ]
            , div [ css [ fontSize (px 10), color (hsl 0 0 0.6) ] ]
                [ text (item.currentDriver |> Maybe.map .name |> Maybe.withDefault "") ]
            ]
        , div [ css [ textAlign Css.right, fontSize (px 11) ] ]
            [ text (Gap.toString item.timing.gap) ]
        ]
