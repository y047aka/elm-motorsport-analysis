module Motorsport.Widget.CarNumberBadge exposing (view, viewRow)

{-| Car number badge on a manufacturer-colored background,
shared by SelectedCarsStrip, LiveStandings, and Compare.

Takes the car's metadata rather than a whole car: who the car is, is all a badge
needs, and none of it moves as the race does.

@docs view, viewRow

-}

import Css exposing (property)
import Html.Styled exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (alt, class, css, src)
import Motorsport.Race.Car as Car
import Motorsport.Wec.Manufacturer as Manufacturer exposing (Manufacturer)


{-| Small stacked badge: logo on top, car number below.
-}
view : (Manufacturer -> Maybe String) -> Car.Metadata -> Html msg
view toLogoUrl metadata =
    badge "flex flex-col items-center justify-center gap-1.5 p-1 rounded w-[35px]"
        [ manufacturerLogo
            [ property "max-width" "28px"
            , property "height" "16px"
            , property "object-fit" "contain"
            , property "opacity" "0.9"
            ]
            toLogoUrl
            metadata.manufacturer
        , div [ class "text-xs font-bold leading-none" ]
            [ text metadata.carNumber ]
        ]
        metadata


{-| Horizontal badge: logo on the left, car number on the right.
-}
viewRow : (Manufacturer -> Maybe String) -> Car.Metadata -> Html msg
viewRow toLogoUrl metadata =
    badge "p-1 grid grid-cols-[20px_25px] gap-1 place-items-center rounded"
        [ manufacturerLogo
            [ property "height" "14px"
            , property "object-fit" "contain"
            ]
            toLogoUrl
            metadata.manufacturer
        , div [ class "text-center leading-none text-xs font-bold" ]
            [ text metadata.carNumber ]
        ]
        metadata


badge : String -> List (Html msg) -> Car.Metadata -> Html msg
badge containerClass children metadata =
    div
        [ class containerClass
        , css [ Css.backgroundColor (Manufacturer.toColor metadata.manufacturer) ]
        ]
        children


manufacturerLogo : List Css.Style -> (Manufacturer -> Maybe String) -> Manufacturer -> Html msg
manufacturerLogo styles toLogoUrl manufacturer =
    case toLogoUrl manufacturer of
        Just url ->
            img [ src url, alt (Manufacturer.toString manufacturer), css styles ] []

        Nothing ->
            div [ css styles ] []
