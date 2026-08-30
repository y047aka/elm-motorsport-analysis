module UI.Shadcn.ButtonGroup exposing (Item, view)

{-| A row of joined action buttons, drawn by shadcn's components behind the
`shadcn-button-group` element.

One element takes the whole row rather than each button taking its own: the
corner-merging between adjacent segments is CSS matching a button's
`data-slot` against its siblings, which only lines up when they share a
parent.

The group holds no selection; a row that picks one of its items is
[`UI.Shadcn.ToggleGroup`](UI-Shadcn-ToggleGroup).

@docs Item, view

-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (property)
import Html.Events
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


type alias Item msg =
    { label : String
    , disabled : Bool
    , onPress : msg
    }


view : { items : List (Item msg) } -> List (Attribute msg) -> Html msg
view config attributes =
    Html.node "shadcn-button-group"
        (property "items" (Encode.list encodeItem config.items)
            :: Html.Events.on "button-group-press" (pressDecoder config.items)
            :: attributes
        )
        []


encodeItem : Item msg -> Encode.Value
encodeItem item =
    Encode.object
        [ ( "label", Encode.string item.label )
        , ( "disabled", Encode.bool item.disabled )
        ]


{-| The element names the pressed item by its index in `items`.
-}
pressDecoder : List (Item msg) -> Decoder msg
pressDecoder items =
    Decode.at [ "detail" ] Decode.int
        |> Decode.andThen
            (\index ->
                case List.drop index items |> List.head of
                    Just item ->
                        Decode.succeed item.onPress

                    Nothing ->
                        Decode.fail ("no button at index " ++ String.fromInt index)
            )
