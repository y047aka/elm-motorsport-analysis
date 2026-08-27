module Motorsport.Widget.Compare.CarSelector exposing (carSelector, classBadge)

{-| Car selector and class badge for the Compare widget.

@docs carSelector, classBadge

-}

import Html.Styled exposing (Html, button, div, text)
import Html.Styled.Attributes as Attributes exposing (style)
import Html.Styled.Events exposing (onClick)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class as Class exposing (Class)


{-| Lays out every car in the given class as chips; clicking a chip toggles its
selection.
-}
carSelector : (String -> msg) -> Snapshot -> Class -> List String -> Html msg
carSelector onToggleCar standings class selectedCarNumbers =
    let
        classCars =
            Snapshot.inClass class standings
    in
    div
        [ Attributes.class "flex flex-wrap gap-1.5" ]
        (List.map
            (\item ->
                carSelectorChip onToggleCar
                    (List.member item.metadata.carNumber selectedCarNumbers)
                    item
            )
            classCars
        )


carSelectorChip : (String -> msg) -> Bool -> CarAt -> Html msg
carSelectorChip onToggleCar isSelected item =
    let
        manufacturerColor =
            item.metadata.manufacturer.color
    in
    button
        ([ onClick (onToggleCar item.metadata.carNumber)
         , Attributes.class "flex items-center gap-x-1 py-0.5 px-2 rounded-full text-[11px] font-bold tabular-nums cursor-pointer text-inherit [font-family:inherit]"
         ]
            ++ (if isSelected then
                    [ style "border" ("1px solid " ++ manufacturerColor)
                    , style "background-color" ("oklch(from " ++ manufacturerColor ++ " l c h / 0.3)")
                    ]

                else
                    [ Attributes.class "border border-[hsl(0_0%_100%/0.2)] bg-transparent opacity-70" ]
               )
        )
        [ text ("#" ++ item.metadata.carNumber) ]


classBadge : Class -> Html msg
classBadge class =
    div
        [ Attributes.class "flex items-center gap-x-1 text-[11px] font-bold whitespace-nowrap before:block before:content-[''] before:w-[0.2em] before:h-[1em] before:rounded-[2px] before:[background-color:var(--class-color)]"
        , Attributes.attribute "style" ("--class-color: " ++ (Class.toColor class).value ++ ";")
        ]
        [ text (Class.toString class) ]
