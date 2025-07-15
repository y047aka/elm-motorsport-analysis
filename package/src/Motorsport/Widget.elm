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
import Html.Styled.Attributes exposing (css)
import Motorsport.Class as Class exposing (Class)


{-| Create a standard widget container with consistent styling
-}
container : String -> Html msg -> Html msg
container widgetTitle content =
    div
        [ css
            [ padding (px 10)
            , borderRadius (px 12)
            , property "display" "grid"
            , property "row-gap" "10px"
            , backgroundColor (hsl 0 0 0.2)
            ]
        ]
        [ title widgetTitle
        , content
        ]


{-| Create a standard widget title with consistent styling
-}
title : String -> Html msg
title titleText =
    h3
        [ css
            [ margin zero
            , fontSize (rem 1.1)
            , fontWeight bold
            , letterSpacing (px 0.5)
            , color (hsl 0 0 0.9)
            ]
        ]
        [ text titleText ]


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
            , color (hsl 0 0 0.9)
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
