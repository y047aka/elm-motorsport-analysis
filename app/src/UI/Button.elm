module UI.Button exposing (view)

{-| Button, drawn by shadcn's Base UI component behind the `shadcn-button`
custom element registered in `index.ts`.

@docs view

-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (property)
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode


{-| Takes its label as a property rather than children: React's synthetic
events never reach a custom element's slotted children, so a button built
from arbitrary `Html msg` children could not report its own clicks.

`variant` and `size` are passed straight through to shadcn's
`buttonVariants` ("default", "outline", "secondary", "ghost", "destructive"
or "link"; "default", "xs", "sm", "lg", "icon", "icon-xs", "icon-sm" or
"icon-lg"). `shape` is this app's own addition to the vendored component,
for the circular playback and close buttons ("default" or "circle").
-}
view :
    { label : String
    , variant : String
    , size : String
    , shape : String
    , disabled : Bool
    , onPress : msg
    }
    -> List (Attribute msg)
    -> Html msg
view config attributes =
    Html.node "shadcn-button"
        (property "label" (Encode.string config.label)
            :: property "variant" (Encode.string config.variant)
            :: property "size" (Encode.string config.size)
            :: property "shape" (Encode.string config.shape)
            :: property "disabled" (Encode.bool config.disabled)
            :: Html.Events.on "button-press" (Decode.succeed config.onPress)
            :: attributes
        )
        []
