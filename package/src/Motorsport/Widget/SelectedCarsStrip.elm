module Motorsport.Widget.SelectedCarsStrip exposing (view)

{-| Widget showing the current overall top cars as side-by-side cards with their
last-lap results, bests, and sector performance. Gives an at-a-glance view of
the front of the race without requiring any selection.

@docs view

-}

import Css exposing (num, opacity, property)
import Html.Styled exposing (Html, button, div, text)
import Html.Styled.Attributes as Attributes exposing (class, css)
import Html.Styled.Events exposing (onClick)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.ViewModel.LapHistory exposing (LapHistory)
import Motorsport.ViewModel.Standings as Standings exposing (Standings)
import Motorsport.Widget.SelectedCarsStrip.CarCard as CarCard


{-| `offset` is the 0-based position of the first card in the visible window.
`onScrollTo` receives the target offset. Out-of-range offsets are clamped
internally, so callers may store them as-is.
-}
view :
    { season : Int
    , analysis : Analysis
    , offset : Int
    , onScrollTo : Int -> msg
    }
    -> { standings : Standings, history : LapHistory }
    -> Html msg
view config { standings, history } =
    let
        allCars =
            Standings.toList standings

        maxOffset =
            max 0 (List.length allCars - displayCount)

        offset =
            clamp 0 maxOffset config.offset

        window =
            allCars
                |> List.drop offset
                |> List.take displayCount
    in
    case window of
        [] ->
            emptyState

        _ ->
            div
                [ css
                    [ property "display" "grid"
                    , property "grid-template-columns" "auto 1fr auto"
                    , property "align-items" "center"
                    , property "column-gap" "8px"
                    ]
                ]
                [ navButton "◀" (config.onScrollTo (offset - 1)) (offset <= 0)
                , div
                    [ css
                        [ property "display" "grid"
                        , property "grid-auto-flow" "column"
                        , property "grid-auto-columns" "minmax(0, 1fr)"
                        , property "column-gap" "8px"
                        ]
                    ]
                    (List.map
                        (CarCard.view
                            { season = config.season, analysis = config.analysis }
                            history
                            allCars
                        )
                        window
                    )
                , navButton "▶" (config.onScrollTo (offset + 1)) (offset >= maxOffset)
                ]


{-| Number of cars shown at once. The carousel scrolls one car at a time.
-}
displayCount : Int
displayCount =
    5


navButton : String -> msg -> Bool -> Html msg
navButton label msg isDisabled =
    button
        [ onClick msg
        , Attributes.disabled isDisabled
        , class "btn btn-circle btn-sm text-xs"
        ]
        [ text label ]


emptyState : Html msg
emptyState =
    div
        [ css
            [ property "display" "grid"
            , property "place-items" "center"
            , property "font-size" "11px"
            , opacity (num 0.5)
            ]
        ]
        [ text "No cars on track" ]
