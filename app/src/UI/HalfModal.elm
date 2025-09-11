module UI.HalfModal exposing (view)

import Css exposing (em, fontSize, height, hover, overflowY, padding2, pct, property, px, scroll, width)
import Css.Global
import Html.Styled as Html exposing (Html, button, div, header)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)
import Svg.Styled as Svg exposing (path, svg)
import Svg.Styled.Attributes as SvgAttr


type alias Props msg =
    { isOpen : Bool
    , onToggle : msg
    , children : List (Html msg)
    }


{-| Half modal component that slides up from the bottom
-}
view : Props msg -> Html msg
view props =
    let
        modalHeight =
            if props.isOpen then
                "85vh"

            else
                "350px"

        modalTransform =
            if props.isOpen then
                "translateY(0)"

            else
                "translateY(calc(100% - 350px))"

        modalTransition =
            "all 0.3s ease"
    in
    div
        [ css
            [ property "position" "absolute"
            , property "bottom" "0"
            , property "left" "0"
            , width (pct 100)
            , property "height" modalHeight
            , padding2 (px 10) (px 15)
            , property "display" "grid"
            , property "row-gap" "10px"
            , property "background-color" "hsl(0 0% 45% / 0.8)"
            , property "backdrop-filter" "blur(10px)"
            , property "border-radius" "16px 16px 0 0"
            , property "box-shadow" "0 -4px 20px hsl(0 0% 0% / 0.1)"
            , property "z-index" "1"
            , property "transform" modalTransform
            , property "transition" modalTransition
            , Css.Global.children
                [ Css.Global.everything [ width (pct 100) ] ]
            ]
        ]
        [ header []
            [ button
                [ onClick props.onToggle
                , css
                    [ width (pct 100)
                    , property "display" "grid"
                    , property "place-items" "center"
                    , property "color" "hsl(0 0% 100% / 0.3)"
                    , fontSize (em 1.2)
                    , property "cursor" "pointer"
                    , padding2 (px 4) (px 6)
                    , property "border-radius" "99px"
                    , property "transition" "all 0.3s ease"
                    , hover
                        [ property "background-color" "hsl(0 0% 100% / 0.05)"
                        , property "color" "hsl(0 0% 100% / 0.5)"
                        , property "border-color" "hsl(0 0% 100% / 0.3)"
                        ]
                    ]
                ]
                [ chevronIcon props.isOpen ]
            ]
        , div [ css [ height (pct 100), overflowY scroll ] ]
            props.children
        ]


chevronIcon : Bool -> Html msg
chevronIcon isOpen =
    let
        pathData =
            if isOpen then
                "M2 7L24 17L46 8"

            else
                "M2 17L24 7L46 17"
    in
    svg
        [ SvgAttr.width "48"
        , SvgAttr.height "24"
        , SvgAttr.viewBox "0 0 48 24"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "5"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        ]
        [ path [ SvgAttr.d pathData ] [] ]
