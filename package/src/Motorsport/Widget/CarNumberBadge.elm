module Motorsport.Widget.CarNumberBadge exposing (view, viewRow)

{-| Car number badge on a manufacturer-colored background,
shared by SelectedCarsStrip, LiveStandings, and Compare.

@docs view, viewRow

-}

import Css exposing (property)
import Html.Styled exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (alt, class, css, src)
import Motorsport.Manufacturer as Manufacturer exposing (Manufacturer)
import Motorsport.ViewModel.Standings exposing (Entry)


{-| Small stacked badge: logo on top, car number below.
-}
view : Entry -> Html msg
view item =
    badge "flex flex-col items-center justify-center gap-1.5 p-1 rounded w-[35px]"
        [ manufacturerLogo
            [ property "max-width" "28px"
            , property "height" "16px"
            , property "object-fit" "contain"
            , property "opacity" "0.9"
            ]
            item.metadata.manufacturer
        , div [ class "text-xs font-bold leading-none" ]
            [ text item.metadata.carNumber ]
        ]
        item


{-| Horizontal badge: logo on the left, car number on the right.
-}
viewRow : Entry -> Html msg
viewRow item =
    badge "p-1 grid grid-cols-[20px_25px] gap-1 place-items-center rounded"
        [ manufacturerLogo
            [ property "height" "14px"
            , property "object-fit" "contain"
            ]
            item.metadata.manufacturer
        , div [ class "text-center leading-none text-xs font-bold" ]
            [ text item.metadata.carNumber ]
        ]
        item


badge : String -> List (Html msg) -> Entry -> Html msg
badge containerClass children item =
    div
        [ class containerClass
        , css [ Css.backgroundColor (Manufacturer.toColor item.metadata.manufacturer) ]
        ]
        children


manufacturerLogo : List Css.Style -> Manufacturer -> Html msg
manufacturerLogo styles manufacturer =
    case Manufacturer.toLogoUrl manufacturer of
        Just url ->
            img [ src url, alt (Manufacturer.toString manufacturer), css styles ] []

        Nothing ->
            div [ css styles ] []
