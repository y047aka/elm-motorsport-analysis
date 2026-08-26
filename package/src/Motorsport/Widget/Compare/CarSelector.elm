module Motorsport.Widget.Compare.CarSelector exposing (carSelector, classBadge)

{-| Car selector and class badge for the Compare widget.

@docs carSelector, classBadge

-}

import Css exposing (num, opacity, property)
import Html.Styled exposing (Html, button, div, text)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class as Class exposing (Class)


{-| Lays out every car in the given class as chips; clicking a chip toggles its
selection.
-}
carSelector : (String -> msg) -> Snapshot -> Class -> List String -> Html msg
carSelector onToggleCar standings class selectedCarNumbers =
    let
        classCars =
            Snapshot.inClass class standings
    in
    div
        [ css
            [ property "display" "flex"
            , property "flex-wrap" "wrap"
            , property "gap" "6px"
            ]
        ]
        (List.map
            (\item ->
                carSelectorChip onToggleCar
                    (List.member item.metadata.carNumber selectedCarNumbers)
                    item
            )
            classCars
        )


carSelectorChip : (String -> msg) -> Bool -> CarAt -> Html msg
carSelectorChip onToggleCar isSelected item =
    let
        manufacturerColor =
            item.metadata.manufacturer.color
    in
    button
        [ onClick (onToggleCar item.metadata.carNumber)
        , css
            [ property "display" "flex"
            , property "align-items" "center"
            , property "column-gap" "4px"
            , property "padding" "2px 8px"
            , property "border-radius" "9999px"
            , property "font-size" "11px"
            , property "font-weight" "700"
            , property "font-variant-numeric" "tabular-nums"
            , property "cursor" "pointer"
            , property "color" "inherit"
            , property "font-family" "inherit"
            , if isSelected then
                Css.batch
                    [ property "border" ("1px solid " ++ manufacturerColor.value)
                    , property "background-color" ("oklch(from " ++ manufacturerColor.value ++ "l c h / 0.3)")
                    ]

              else
                Css.batch
                    [ property "border" "1px solid hsl(0 0% 100% / 0.2)"
                    , property "background-color" "transparent"
                    , opacity (num 0.7)
                    ]
            ]
        ]
        [ text ("#" ++ item.metadata.carNumber) ]


classBadge : Class -> Html msg
classBadge class =
    div
        [ css
            [ property "display" "flex"
            , property "align-items" "center"
            , property "column-gap" "4px"
            , property "font-size" "11px"
            , property "font-weight" "700"
            , property "white-space" "nowrap"
            , Css.before
                [ property "display" "block"
                , property "content" (Css.qt "")
                , property "width" "0.2em"
                , property "height" "1em"
                , property "border-radius" "2px"
                , Css.property "background-color" (Class.toColor class).value
                ]
            ]
        ]
        [ text (Class.toString class) ]
