module View.CarNumberBadge exposing (view, viewCompact, viewRow)

{-| Car number badge on a manufacturer-coloured background.

@docs view, viewCompact, viewRow

-}

import Html exposing (Html, div, img, text)
import Html.Attributes exposing (alt, class, src, style)
import Motorsport.Manufacturer exposing (Manufacturer)
import Motorsport.Race.Car as Car


{-| Small stacked badge: logo on top, car number below.
-}
view : Car.Metadata -> Html msg
view metadata =
    badge "flex flex-col items-center justify-center gap-1.5 p-1 rounded w-[35px]"
        [ manufacturerLogo "max-w-[28px] h-4 object-contain opacity-90" metadata.manufacturer
        , div [ class "text-xs font-bold leading-none" ]
            [ text metadata.carNumber ]
        ]
        metadata


{-| The stacked badge of a dense list: the maker's logo over the number on
their colour, at a third less bulk than the nameplate's. The colour is the
maker's own -- what keeps a sixty-two-row list from shouting is the size,
not a thinner wash of it.
-}
viewCompact : Car.Metadata -> Html msg
viewCompact metadata =
    badge "flex flex-col items-center justify-center gap-[2px] p-[3px] rounded-[3px] w-[26px]"
        [ manufacturerLogo "max-w-[18px] h-[11px] object-contain" metadata.manufacturer
        , div [ class "text-[10px] font-bold leading-none" ]
            [ text metadata.carNumber ]
        ]
        metadata


{-| Horizontal badge: the maker's logo on their colour, and the car number
beside it as plain text on nothing. Its `1.375rem` height is what the
timeline builds its lines on.
-}
viewRow : Car.Metadata -> Html msg
viewRow metadata =
    div [ class "h-[1.375rem] flex items-center gap-1" ]
        [ div
            [ class "w-5 grid place-items-center p-0.5 rounded-[3px]"
            , style "background-color" metadata.manufacturer.color
            ]
            [ manufacturerLogo "h-[14px] max-w-full object-contain" metadata.manufacturer ]
        , div [ class "w-[25px] text-center leading-none text-xs font-bold" ]
            [ text metadata.carNumber ]
        ]


badge : String -> List (Html msg) -> Car.Metadata -> Html msg
badge containerClass children metadata =
    div
        [ class containerClass
        , style "background-color" metadata.manufacturer.color
        ]
        children


manufacturerLogo : String -> Manufacturer -> Html msg
manufacturerLogo logoClass manufacturer =
    case manufacturer.logoUrl of
        Just url ->
            img [ src url, alt manufacturer.name, class logoClass ] []

        Nothing ->
            div [ class logoClass ] []
