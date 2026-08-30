module UI.Shadcn.Button exposing (Variant(..), Size(..), Shape(..), view)

{-| Button, drawn by shadcn's Base UI component behind the `shadcn-button`
custom element registered in `index.ts`.

@docs Variant, Size, Shape, view

-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (property)
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode


{-| The `variant` axis of shadcn's `buttonVariants`. `Primary` is the one it
calls "default".
-}
type Variant
    = Primary
    | Outline
    | Secondary
    | Ghost
    | Destructive
    | Link


{-| The `size` axis of shadcn's `buttonVariants`. `Medium` is the one it calls
"default", and it sits between `Small` and `Large`.
-}
type Size
    = Medium
    | ExtraSmall
    | Small
    | Large
    | Icon
    | IconExtraSmall
    | IconSmall
    | IconLarge


{-| This app's own addition to the vendored component, for the circular
playback and close buttons.
-}
type Shape
    = Rectangle
    | Circle


{-| Takes its label as a property rather than children: React's synthetic
events never reach a custom element's slotted children, so a button built
from arbitrary `Html msg` children could not report its own clicks.
-}
view :
    { label : String
    , variant : Variant
    , size : Size
    , shape : Shape
    , disabled : Bool
    , onPress : msg
    }
    -> List (Attribute msg)
    -> Html msg
view config attributes =
    Html.node "shadcn-button"
        (property "label" (Encode.string config.label)
            :: property "variant" (encodeVariant config.variant)
            :: property "size" (encodeSize config.size)
            :: property "shape" (encodeShape config.shape)
            :: property "disabled" (Encode.bool config.disabled)
            :: Html.Events.on "button-press" (Decode.succeed config.onPress)
            :: attributes
        )
        []


encodeVariant : Variant -> Encode.Value
encodeVariant variant =
    Encode.string <|
        case variant of
            Primary ->
                "default"

            Outline ->
                "outline"

            Secondary ->
                "secondary"

            Ghost ->
                "ghost"

            Destructive ->
                "destructive"

            Link ->
                "link"


encodeSize : Size -> Encode.Value
encodeSize size =
    Encode.string <|
        case size of
            Medium ->
                "default"

            ExtraSmall ->
                "xs"

            Small ->
                "sm"

            Large ->
                "lg"

            Icon ->
                "icon"

            IconExtraSmall ->
                "icon-xs"

            IconSmall ->
                "icon-sm"

            IconLarge ->
                "icon-lg"


encodeShape : Shape -> Encode.Value
encodeShape shape =
    Encode.string <|
        case shape of
            Rectangle ->
                "default"

            Circle ->
                "circle"
