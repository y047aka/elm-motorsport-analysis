module View.CarNumberBadge exposing (circle, view, viewAvatar, viewCompact, viewRow)

{-| The maker's mark over the car's number, on the maker's colour.

Four shapes, one drawing: the plate a car is named by, the small plate a class
column keeps, the row a timing line is as tall as, and the circle a feed posts
with. What differs between them is the box, and the ratio between the mark, the
number and the space left between them -- so a ratio here is read against the
others, not invented.

@docs circle, view, viewAvatar, viewCompact, viewRow

-}

import Html exposing (Html, div, img, text)
import Html.Attributes exposing (alt, class, src, style)
import Motorsport.Manufacturer exposing (Manufacturer)
import Motorsport.Race.Car as Car


{-| Small stacked badge: logo on top, car number below.
-}
view : Car.Metadata -> Html msg
view metadata =
    stacked
        { box = "gap-1.5 p-1 rounded w-[35px]"
        , logo = "max-w-[28px] h-4 object-contain opacity-90"
        , label = "text-xs font-bold leading-none"
        }
        metadata


{-| The stacked badge of a dense list: the maker's logo over the number on
their colour, at a third less bulk than the nameplate's. The colour is the
maker's own -- what keeps a sixty-two-row list from shouting is the size,
not a thinner wash of it.
-}
viewCompact : Car.Metadata -> Html msg
viewCompact metadata =
    stacked
        { box = "gap-[2px] p-[3px] rounded-[3px] w-[26px]"
        , logo = "max-w-[18px] h-[11px] object-contain"
        , label = "text-[10px] font-bold leading-none"
        }
        metadata


{-| The circle a feed posts a car with, at the ratio the two plates set between
them: `view` carries `text-xs` on `w-[35px]` and `viewCompact` carries
`text-[10px]` on `w-[26px]`, so 32px takes `text-[11px]` for the number.

The mark is a hair under the 14px `viewRow` gives it, and the circle keeps 3px of
padding: a plate's content reaches its corners, a circle's reaches its curve, and
the same figure reads tighter in the round.

-}
viewAvatar : Car.Metadata -> Html msg
viewAvatar metadata =
    circle
        { ground = "text-[11px] font-bold"
        , colour = Just metadata.manufacturer.color
        , label = metadata.carNumber
        , mark =
            Maybe.map
                (\url -> { src = url, alt = metadata.manufacturer.name })
                metadata.manufacturer.logoUrl
        }


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


{-| The circle: a label on a ground the caller names, under a mark where there is
one. A car's avatar and a field event's race-control mark are the same circle; what
the shape cannot know is the number's size and the ground's colour, so the caller
brings both.

A maker with no mark centres its number where the mark would have stood. The plates
keep the empty box instead, which is what holds their height.

-}
circle :
    { ground : String
    , colour : Maybe String
    , label : String
    , mark : Maybe { src : String, alt : String }
    }
    -> Html msg
circle { ground, colour, label, mark } =
    let
        background =
            Maybe.map (\back -> [ style "background-color" back ]) colour
                |> Maybe.withDefault []
    in
    div
        ([ class ("flex flex-col items-center justify-center gap-[2px] size-8 shrink-0 rounded-full p-[3px] leading-none " ++ ground) ]
            ++ background
        )
        [ case mark of
            Just drawn ->
                img [ src drawn.src, alt drawn.alt, class "max-h-[13px] max-w-[21px] object-contain" ] []

            Nothing ->
                text ""
        , div [ class "leading-none" ] [ text label ]
        ]


{-| The mark over the number, in the box a plate is.
-}
stacked : { box : String, logo : String, label : String } -> Car.Metadata -> Html msg
stacked { box, logo, label } metadata =
    div
        [ class ("flex flex-col items-center justify-center " ++ box)
        , style "background-color" metadata.manufacturer.color
        ]
        [ manufacturerLogo logo metadata.manufacturer
        , div [ class label ] [ text metadata.carNumber ]
        ]


manufacturerLogo : String -> Manufacturer -> Html msg
manufacturerLogo logoClass manufacturer =
    case manufacturer.logoUrl of
        Just url ->
            img [ src url, alt manufacturer.name, class logoClass ] []

        Nothing ->
            div [ class logoClass ] []
