module UI.Badge exposing (view)

{-| Badge, drawn by shadcn's Base UI component behind the `shadcn-badge`
custom element registered in `index.ts`.

@docs view

-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (property)
import Json.Encode as Encode


{-| `variant` is passed straight through to shadcn's `badgeVariants`
("default", "secondary", "destructive", "outline", "outline-primary",
"ghost" or "link").
-}
view : { label : String, variant : String } -> List (Attribute msg) -> Html msg
view config attributes =
    Html.node "shadcn-badge"
        (property "label" (Encode.string config.label)
            :: property "variant" (Encode.string config.variant)
            :: attributes
        )
        []
