module UI.Shadcn.Slider exposing (view)

{-| Slider, drawn by shadcn's Base UI component behind the `shadcn-slider`
custom element registered in `index.ts`.

@docs view

-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (property)
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode


{-| `onChange` receives the position the drag landed on. The element holds no
position of its own, so a caller that ignores this leaves the thumb where it
was.
-}
view :
    { min : Int
    , max : Int
    , value : Int
    , onChange : Int -> msg
    }
    -> List (Attribute msg)
    -> Html msg
view config attributes =
    Html.node "shadcn-slider"
        (property "min" (Encode.int config.min)
            :: property "max" (Encode.int config.max)
            :: property "value" (Encode.int config.value)
            -- Base UI reports the position as a plain number, which is not
            -- necessarily integral, and a decoder that fails is dropped in
            -- silence rather than reported.
            :: Html.Events.on "slider-change"
                (Decode.at [ "detail" ] Decode.float
                    |> Decode.map (round >> config.onChange)
                )
            :: attributes
        )
        []
