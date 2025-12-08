module Motorsport.Widget.Compare exposing (Model, Msg(..), Props, init, update, viewCarSelector, viewCharts)

import Css exposing (backgroundColor, property)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (class, css, src)
import Html.Styled.Events exposing (onClick)
import List.Extra
import List.NonEmpty as NonEmpty
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.BoxPlot as BoxPlot
import Motorsport.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Leaderboard as Leaderboard
import Motorsport.Manufacturer
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget.CloseBattles as CloseBattles
import Motorsport.Widget.Compare.LapTimeProgression as LapTimeProgression
import Motorsport.Widget.Compare.PositionProgression as PositionProgression
import SortedList



-- TYPES


type alias Model =
    { selectedCars : List String }


init : Model
init =
    { selectedCars = [] }


type Msg
    = ToggleCar String


update : Msg -> Model -> Model
update msg model =
    case msg of
        ToggleCar carNumber ->
            if List.member carNumber model.selectedCars then
                { selectedCars = List.filter ((/=) carNumber) model.selectedCars }

            else
                { selectedCars = model.selectedCars ++ [ carNumber ] }



-- Props


type alias Props =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , clock : Clock.Model
    , analysis : Analysis
    }



-- VIEW


viewCharts : Props -> Model -> Html Msg
viewCharts props model =
    let
        selectedCars =
            resolveCars model.selectedCars props.viewModel
                |> List.sortBy .position
    in
    div
        [ css
            [ property "display" "flex"
            , property "flex-direction" "column"
            , property "gap" "12px"
            ]
        ]
        [ PositionProgression.view
            props.clock
            props.viewModel
            selectedCars
        , LapTimeProgression.view
            props.clock
            props.viewModel
            selectedCars
        , selectedCars
            |> List.sortBy .position
            |> NonEmpty.fromList
            |> Maybe.map
                (\cars ->
                    let
                        leader =
                            NonEmpty.head cars
                    in
                    CloseBattles.closeBattleItem
                        { cars = cars
                        , position = leader.position
                        }
                )
            |> Maybe.withDefault (text "")
        , BoxPlot.view props.analysis selectedCars
        ]


resolveCars : List String -> ViewModel -> List ViewModelItem
resolveCars carNumbers viewModel =
    carNumbers
        |> List.filterMap
            (\carNumber ->
                viewModel.items
                    |> SortedList.toList
                    |> List.Extra.find (\item -> item.metadata.carNumber == carNumber)
            )


viewCarSelector : Props -> Model -> Html Msg
viewCarSelector props model =
    div
        [ css
            [ property "display" "flex"
            , property "flex-wrap" "wrap"
            , property "gap" "8px"
            , property "min-width" "0"
            , property "width" "100%"
            ]
        ]
        (props.viewModel.items
            |> SortedList.toList
            |> List.map (carSelectorItem model)
        )


carSelectorItem : Model -> ViewModelItem -> Html Msg
carSelectorItem model item =
    let
        isSelected =
            List.member item.metadata.carNumber model.selectedCars

        manufacturerColor =
            Motorsport.Manufacturer.toColor item.metadata.manufacturer

        borderStyle =
            if isSelected then
                "2px solid hsl(0 0% 100% / 0.5)"

            else
                "2px solid transparent"

        overlayOpacity =
            if isSelected then
                "0"

            else
                "0.3"
    in
    div
        [ css
            [ property "min-width" "70px"
            , property "width" "70px"
            , property "border" borderStyle
            , property "border-radius" "8px"
            , Css.backgroundColor manufacturerColor
            , property "cursor" "pointer"
            , property "transition" "all 0.2s"
            , property "position" "relative"
            , property "overflow" "hidden"
            ]
        , onClick (ToggleCar item.metadata.carNumber)
        ]
        [ -- Dark overlay for unselected items
          div
            [ css
                [ property "position" "absolute"
                , property "inset" "0"
                , property "background-color" "hsl(0 0% 0%)"
                , property "opacity" overlayOpacity
                , property "transition" "opacity 0.2s"
                , property "pointer-events" "none"
                ]
            ]
            []
        , div
            [ css
                [ property "padding" "8px"
                , property "display" "flex"
                , property "flex-direction" "column"
                , property "align-items" "center"
                , property "gap" "6px"
                , property "position" "relative"
                ]
            ]
            [ -- Position
              div
                [ css
                    [ property "font-size" "10px"
                    , property "font-weight" "700"
                    , property "line-height" "1"
                    , property "color" "hsl(0 0% 100%)"
                    , property "opacity" "0.8"
                    ]
                ]
                [ text ("P" ++ String.fromInt item.position) ]
            , -- Manufacturer logo
              manufacturerLogo item.metadata.manufacturer
            , -- Car number
              div
                [ css
                    [ property "font-size" "22px"
                    , property "font-weight" "700"
                    , property "line-height" "1"
                    , property "color" "hsl(0 0% 100%)"
                    ]
                ]
                [ text item.metadata.carNumber ]
            , -- Class indicator
              div
                [ css
                    [ property "font-size" "8px"
                    , property "font-weight" "600"
                    , property "line-height" "1"
                    , property "text-transform" "uppercase"
                    , property "color" "hsl(0 0% 100%)"
                    , property "opacity" "0.8"
                    ]
                ]
                [ text (Class.toString item.metadata.class) ]
            ]
        ]


manufacturerLogo : Motorsport.Manufacturer.Manufacturer -> Html msg
manufacturerLogo manufacturer =
    case Motorsport.Manufacturer.toLogoUrl manufacturer of
        Just url ->
            img
                [ src url
                , css
                    [ property "max-width" "40px"
                    , property "height" "24px"
                    , property "object-fit" "contain"
                    , property "opacity" "0.9"
                    ]
                ]
                []

        Nothing ->
            div
                [ css
                    [ property "width" "36px"
                    , property "height" "24px"
                    ]
                ]
                []
