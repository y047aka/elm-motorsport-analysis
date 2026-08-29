module UI.ButtonGroup exposing (Item, view)

{-| A row of joined action buttons, drawn by shadcn's Base UI components behind
the `shadcn-button-group` custom element registered in `index.ts`.

The group is rendered as one React tree rather than as separately-mounted
`UI.Button`s: the corner-merging between adjacent segments is plain CSS
matching each button's own `data-slot` against its siblings, which only
lines up when every button in the group shares a parent.

The group holds no selection; a row that picks one of its items is
[`UI.ToggleGroup`](UI-ToggleGroup).

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
