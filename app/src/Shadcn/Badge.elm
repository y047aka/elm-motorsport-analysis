module Shadcn.Badge exposing (Variant(..), view)

{-| Badge, drawn by shadcn's Base UI component behind the `shadcn-badge`
custom element registered in `index.ts`.

@docs Variant, view

-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (property)
import Json.Encode as Encode


{-| The `variant` axis of shadcn's `badgeVariants`. `Primary` is the one it
calls "default"; `OutlinePrimary` is this app's own addition to the vendored
component.
-}
type Variant
    = Primary
    | Secondary
    | Destructive
    | Outline
    | OutlinePrimary
    | Ghost
    | Link


view : { label : String, variant : Variant } -> List (Attribute msg) -> Html msg
view config attributes =
    Html.node "shadcn-badge"
        (property "label" (Encode.string config.label)
            :: property "variant" (encodeVariant config.variant)
            :: attributes
        )
        []


encodeVariant : Variant -> Encode.Value
encodeVariant variant =
    Encode.string <|
        case variant of
            Primary ->
                "default"

            Secondary ->
                "secondary"

            Destructive ->
                "destructive"

            Outline ->
                "outline"

            OutlinePrimary ->
                "outline-primary"

            Ghost ->
                "ghost"

            Link ->
                "link"
