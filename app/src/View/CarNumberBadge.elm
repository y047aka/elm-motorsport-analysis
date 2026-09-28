module View.CarNumberBadge exposing (view, viewLegend, viewRow)

{-| Car number badge on a manufacturer-coloured background.

@docs view, viewLegend, viewRow

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


{-| The quiet form, for a list that wants the cars named rather than drawn:
the manufacturer's colour sits behind the logo alone and the number is plain
text. The footprint is the row's, so a column of these sits in one line.
-}
viewLegend : Car.Metadata -> Html msg
viewLegend metadata =
    div [ class "p-1 grid grid-cols-[20px_25px] gap-1 place-items-center" ]
        [ div
            [ class "p-0.5 rounded-[3px]"
            , style "background-color" metadata.manufacturer.color
            ]
            [ manufacturerLogo "h-[14px] object-contain" metadata.manufacturer ]
        , div [ class "text-center leading-none text-xs" ]
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
