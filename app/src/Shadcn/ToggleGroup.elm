module Shadcn.ToggleGroup exposing (Item, view)

{-| A row of joined buttons of which exactly one is pressed, drawn by shadcn's
Base UI components behind the `shadcn-toggle-group` custom element registered
in `index.ts`.

Base UI gives each item `aria-pressed` and makes the whole row one arrow-key
stop. A row of independent actions, carrying no selection, is
[`Shadcn.ButtonGroup`](Shadcn-ButtonGroup).

@docs Item, view

-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (property)
import Html.Events
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


type alias Item msg =
    { label : String
    , active : Bool
    , disabled : Bool
    , onSelect : msg
    }


view : { items : List (Item msg) } -> List (Attribute msg) -> Html msg
view config attributes =
    Html.node "shadcn-toggle-group"
        (property "items" (Encode.list encodeItem config.items)
            :: Html.Events.on "toggle-group-press" (selectDecoder config.items)
            :: attributes
        )
        []


encodeItem : Item msg -> Encode.Value
encodeItem item =
    Encode.object
        [ ( "label", Encode.string item.label )
        , ( "active", Encode.bool item.active )
        , ( "disabled", Encode.bool item.disabled )
        ]


{-| The element names the selected item by its index in `items`.
-}
selectDecoder : List (Item msg) -> Decoder msg
selectDecoder items =
    Decode.at [ "detail" ] Decode.int
        |> Decode.andThen
            (\index ->
                case List.drop index items |> List.head of
                    Just item ->
                        Decode.succeed item.onSelect

                    Nothing ->
                        Decode.fail ("no item at index " ++ String.fromInt index)
            )
