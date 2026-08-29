module UI.ButtonGroup exposing (Item, view)

{-| A row of segmented buttons, drawn by shadcn's Base UI components behind
the `shadcn-button-group` custom element registered in `index.ts`.

The group is rendered as one React tree rather than as separately-mounted
`UI.Button`s: the corner-merging between adjacent segments is plain CSS
matching each button's own `data-slot` against its siblings, which only
lines up when every button in the group shares a parent.

@docs Item, view

-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (property)
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode


type alias Item =
    { value : String
    , label : String
    , active : Bool
    , disabled : Bool
    }


{-| `onPress` receives the `value` of whichever item was pressed.
-}
view : { items : List Item, onPress : String -> msg } -> List (Attribute msg) -> Html msg
view config attributes =
    Html.node "shadcn-button-group"
        (property "items" (Encode.list encodeItem config.items)
            :: Html.Events.on "button-group-press"
                (Decode.at [ "detail" ] Decode.string |> Decode.map config.onPress)
            :: attributes
        )
        []


encodeItem : Item -> Encode.Value
encodeItem item =
    Encode.object
        [ ( "value", Encode.string item.value )
        , ( "label", Encode.string item.label )
        , ( "active", Encode.bool item.active )
        , ( "disabled", Encode.bool item.disabled )
        ]
