module Motorsport.Widget exposing
    ( container
    , classHeader, emptyState
    )

{-|

@docs container
@docs classHeader, emptyState

-}

import Css exposing (..)
import Html.Styled as Html exposing (Html, div, h3, text)
import Html.Styled.Attributes exposing (class, css)
import Motorsport.Class as Class exposing (Class)


{-| Create a standard widget container with consistent styling
-}
container : String -> Html msg -> Html msg
container widgetTitle content =
    div
        [ class "card card-sm"
        , css [ property "background-color" "var(--widget-bg)" ]
        ]
        [ div [ class "card-body" ]
            [ h3 [ class "card-title" ] [ text widgetTitle ]
            , content
            ]
        ]


{-| Create a consistent empty state message
-}
emptyState : String -> Html msg
emptyState message =
    div
        [ css
            [ padding (px 20)
            , textAlign center
            , fontStyle italic
            , color (hsl 0 0 0.7)
            ]
        ]
        [ text message ]


{-| Create a class header with class indicator and name, plus additional content
-}
classHeader : Class -> List (Html msg) -> Html msg
classHeader class additionalContent =
    div
        [ css
            [ property "display" "flex"
            , justifyContent spaceBetween
            , alignItems center
            , property "column-gap" "5px"
            , fontSize (px 14)
            , property "font-weight" "600"
            ]
        ]
        [ div
            [ css
                [ property "display" "grid"
                , property "grid-template-columns" "auto 1fr"
                , alignItems center
                , property "column-gap" "5px"
                , before
                    [ property "content" (qt "")
                    , display block
                    , width (px 15)
                    , height (px 15)
                    , backgroundColor (Class.toHexColor 2025 class)
                    , borderRadius (px 4)
                    ]
                ]
            ]
            [ text (Class.toString class) ]
        , div [ css [ fontSize (rem 0.75), color (hsl 0 0 0.6) ] ]
            additionalContent
        ]
