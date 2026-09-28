module View.CarNumberBadge exposing (manufacturerBadge, view, viewRow, viewRowPlain)

{-| Car number badge on a manufacturer-coloured background.

@docs manufacturerBadge, view, viewRow, viewRowPlain

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


{-| `viewRow` with nothing behind the logo -- for a list whose colour lives
elsewhere and a plate would only paint over it. Same cells, same height, so
the two lists still draw their rows to one measure.
-}
viewRowPlain : Car.Metadata -> Html msg
viewRowPlain metadata =
    row False metadata


{-| Horizontal badge: the maker's logo on their colour, and the car number
beside it as plain text on nothing. Its `1.375rem` height is what the
timeline builds its lines on.
-}
viewRow : Car.Metadata -> Html msg
viewRow metadata =
    row True metadata


row : Bool -> Car.Metadata -> Html msg
row coloured metadata =
    div [ class "h-[1.375rem] flex items-center gap-1" ]
        [ div
            ([ class "w-5 grid place-items-center p-0.5 rounded-[3px]" ]
                ++ (if coloured then
                        [ style "background-color" metadata.manufacturer.color ]

                    else
                        []
                   )
            )
            [ manufacturerLogo "h-[14px] max-w-full object-contain" metadata.manufacturer ]
        , div [ class "w-[25px] text-center leading-none text-xs font-bold" ]
            [ text metadata.carNumber ]
        ]


{-| The maker's own mark: the logo alone, on a width every badge shares so
that a column of them lines up whatever shape the artwork's own is. It wears
no colour; a row that says whose car it is takes the colour from the car.
-}
manufacturerBadge : Manufacturer -> Html msg
manufacturerBadge manufacturer =
    div [ class "w-5 grid place-items-center" ]
        [ manufacturerLogo "h-[14px] max-w-full object-contain" manufacturer ]


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
