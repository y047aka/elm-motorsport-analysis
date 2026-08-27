module Motorsport.Widget.CarNumberBadge exposing (view, viewRow)

{-| Car number badge on a manufacturer-colored background,
shared by SelectedCarsStrip, LiveStandings, and Compare.

Takes the car's metadata rather than a whole car: who the car is, is all a badge
needs, and none of it moves as the race does.

@docs view, viewRow

-}

import Html.Styled exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (alt, class, src, style)
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


{-| Horizontal badge: logo on the left, car number on the right.
-}
viewRow : Car.Metadata -> Html msg
viewRow metadata =
    badge "p-1 grid grid-cols-[20px_25px] gap-1 place-items-center rounded"
        [ manufacturerLogo "h-[14px] object-contain" metadata.manufacturer
        , div [ class "text-center leading-none text-xs font-bold" ]
            [ text metadata.carNumber ]
        ]
        metadata


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
