module Shadcn.Card exposing (card, header, title, description, action, content, footer)

{-| Card, drawn by the custom elements `card-elements.ts` registers. Unlike the
other wrappers here these carry no React: Card's classes read what it contains,
so its parts and the content Elm puts in them have to be one tree.

Nothing takes a `class`. Each element sets its own, and layout around a card
belongs to whatever the caller wraps it in.

@docs card, header, title, description, action, content, footer

-}

import Html exposing (Attribute, Html)


card : List (Attribute msg) -> List (Html msg) -> Html msg
card =
    Html.node "shadcn-card"


header : List (Attribute msg) -> List (Html msg) -> Html msg
header =
    Html.node "shadcn-card-header"


title : List (Attribute msg) -> List (Html msg) -> Html msg
title =
    Html.node "shadcn-card-title"


description : List (Attribute msg) -> List (Html msg) -> Html msg
description =
    Html.node "shadcn-card-description"


{-| Sits in the header's second column, opposite the title.
-}
action : List (Attribute msg) -> List (Html msg) -> Html msg
action =
    Html.node "shadcn-card-action"


content : List (Attribute msg) -> List (Html msg) -> Html msg
content =
    Html.node "shadcn-card-content"


footer : List (Attribute msg) -> List (Html msg) -> Html msg
footer =
    Html.node "shadcn-card-footer"
