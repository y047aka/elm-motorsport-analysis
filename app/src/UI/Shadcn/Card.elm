module UI.Shadcn.Card exposing (card, header, title, description, action, content, footer)

{-| Card, drawn by the elements `card-elements.ts` registers. Alone among the
wrappers here it mounts no React, so Elm's content sits in Card's own tree.

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
