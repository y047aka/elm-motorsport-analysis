module Motorsport.Widget.Compare exposing (Model, Msg(..), Props, init, update, viewCarSelector, viewCharts)

import Css exposing (backgroundColor, batch, before, borderRadius, height, pct, property, px, qt, width)
import Css.Color exposing (oklch)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled exposing (Html, button, div, img, text)
import Html.Styled.Attributes exposing (class, css, src)
import Html.Styled.Events exposing (onClick)
import List.Extra
import List.NonEmpty as NonEmpty
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car as Car
import Motorsport.Chart.BoxPlot as BoxPlot
import Motorsport.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Lap.Performance as Performance exposing (performanceLevel)
import Motorsport.Manufacturer
import Motorsport.Sector exposing (Sector(..))
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Motorsport.Widget.CloseBattles as CloseBattles
import Motorsport.Widget.Compare.LapTimeProgression as LapTimeProgression
import Motorsport.Widget.Compare.PositionProgression as PositionProgression



-- TYPES


type ActiveChart
    = PositionProgressionChart
    | LapTimeProgressionChart
    | CloseBattlesChart
    | BoxPlotChart


type alias Model =
    { selectedCars : List String
    , activeChart : ActiveChart
    }


init : Model
init =
    { selectedCars = []
    , activeChart = PositionProgressionChart
    }


type Msg
    = ToggleCar String
    | SwitchChart ActiveChart


update : Msg -> Model -> Model
update msg model =
    case msg of
        ToggleCar carNumber ->
            if List.member carNumber model.selectedCars then
                { model | selectedCars = List.filter ((/=) carNumber) model.selectedCars }

            else
                { model | selectedCars = model.selectedCars ++ [ carNumber ] }

        SwitchChart chart ->
            { model | activeChart = chart }



-- Props


type alias Props =
    { eventSummary : EventSummary
    , standings : Standings
    , clock : Clock.Model
    , analysis : Analysis
    }



-- VIEW


viewCharts : { width : Float, height : Float } -> Props -> Model -> Html Msg
viewCharts size props model =
    let
        selectedCars =
            resolveCars model.selectedCars props.standings
                |> List.sortBy .position
    in
    div
        [ css
            [ property "display" "flex"
            , property "flex-direction" "column"
            , property "gap" "8px"
            ]
        ]
        [ viewChartTabs model.activeChart
        , viewActiveChart model.activeChart size props selectedCars
        ]


viewChartTabs : ActiveChart -> Html Msg
viewChartTabs activeChart =
    div [ class "join" ]
        [ chartTabButton "Position" PositionProgressionChart (activeChart == PositionProgressionChart)
        , chartTabButton "Lap Time" LapTimeProgressionChart (activeChart == LapTimeProgressionChart)
        , chartTabButton "Battles" CloseBattlesChart (activeChart == CloseBattlesChart)
        , chartTabButton "Box Plot" BoxPlotChart (activeChart == BoxPlotChart)
        ]


chartTabButton : String -> ActiveChart -> Bool -> Html Msg
chartTabButton label chart isActive =
    button
        [ onClick (SwitchChart chart)
        , class
            ("join-item btn btn-sm btn-soft"
                ++ (if isActive then
                        " btn-active"

                    else
                        ""
                   )
            )
        ]
        [ text label ]


viewActiveChart : ActiveChart -> { width : Float, height : Float } -> Props -> List StandingsEntry -> Html Msg
viewActiveChart activeChart size props selectedCars =
    case activeChart of
        PositionProgressionChart ->
            PositionProgression.view
                size
                props.clock
                props.standings
                selectedCars

        LapTimeProgressionChart ->
            LapTimeProgression.view
                size
                props.clock
                props.standings
                selectedCars

        CloseBattlesChart ->
            selectedCars
                |> List.sortBy .position
                |> NonEmpty.fromList
                |> Maybe.map
                    (\cars ->
                        let
                            leader =
                                NonEmpty.head cars
                        in
                        CloseBattles.closeBattleItem
                            size
                            props.standings
                            { cars = cars
                            , position = leader.position
                            }
                    )
                |> Maybe.withDefault (text "")

        BoxPlotChart ->
            BoxPlot.view size props.analysis props.standings selectedCars


resolveCars : List String -> Standings -> List StandingsEntry
resolveCars carNumbers standings =
    carNumbers
        |> List.filterMap
            (\carNumber ->
                Standings.toList standings
                    |> List.Extra.find (\item -> item.metadata.carNumber == carNumber)
            )


viewCarSelector : Props -> Model -> Html Msg
viewCarSelector props model =
    let
        groupedByClass =
            Standings.toList props.standings
                |> List.Extra.gatherEqualsBy (.metadata >> .class)
                |> List.map (\( first, rest ) -> first :: rest)
    in
    div
        [ css
            [ property "display" "flex"
            , property "gap" "10px"
            , property "flex-wrap" "wrap"
            ]
        ]
        (List.map (viewClassGroup props.analysis model) groupedByClass)


viewClassGroup : Analysis -> Model -> List StandingsEntry -> Html Msg
viewClassGroup analysis model cars =
    case List.head cars of
        Nothing ->
            text ""

        Just firstCar ->
            div
                [ class "card bg-base-200"
                , css
                    [ property "flex" "1"
                    , property "min-width" "200px"
                    ]
                ]
                [ div
                    [ class "card-body p-3 gap-2" ]
                    [ -- Class header
                      div
                        [ css
                            [ property "display" "flex"
                            , property "align-items" "center"
                            , property "column-gap" "0.5em"
                            , property "font-size" "10px"
                            , property "font-weight" "700"
                            , property "color" "hsl(0 0% 100% / 0.8)"
                            , before
                                [ property "display" "block"
                                , property "content" (qt "")
                                , property "width" "0.2em"
                                , property "height" "1.2em"
                                , property "border-radius" "2px"
                                , backgroundColor (Class.toHexColor 2025 firstCar.metadata.class)
                                ]
                            ]
                        ]
                        [ text (Class.toString firstCar.metadata.class) ]
                    , -- Car grid
                      div
                        [ css
                            [ property "display" "grid"
                            , property "grid-template-columns" "repeat(auto-fill, minmax(35px, 1fr))"
                            , property "gap" "2px"
                            ]
                        ]
                        (List.map (carSelectorItem analysis model) cars)
                    ]
                ]


carSelectorItem : Analysis -> Model -> StandingsEntry -> Html Msg
carSelectorItem analysis model item =
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

        opacity =
            if isSelected then
                "1.0"

            else
                "0.5"
    in
    div
        [ class "stat p-0.5 place-items-center gap-1.5 rounded cursor-pointer"
        , css
            [ property "border" borderStyle
            , property "background-color" ("oklch(from " ++ manufacturerColor.value ++ "l c h / " ++ opacity ++ ")")
            , property "transition" "all 0.2s"
            ]
        , onClick (ToggleCar item.metadata.carNumber)
        ]
        [ -- Manufacturer logo
          manufacturerLogo item.metadata.manufacturer
        , -- Car number
          div
            [ class "stat-value text-xs leading-none" ]
            [ text item.metadata.carNumber ]
        , -- Sector progress
          sectorProgressBar analysis item
        ]


sectorProgressBar : Analysis -> StandingsEntry -> Html msg
sectorProgressBar analysis item =
    let
        sectorBar sector_ =
            div
                [ css
                    [ height (px 2)
                    , borderRadius (px 1)
                    , batch <|
                        if sector_.progress < 100 then
                            [ width (pct sector_.progress)
                            , backgroundColor (oklch 1 0 0)
                            ]

                        else
                            [ width (pct 100)
                            , property "background-color"
                                (performanceLevel sector_
                                    |> Performance.toColorVariable
                                )
                            ]
                    ]
                ]
                []
    in
    if Car.hasRetired item.status then
        div [ css [ width (pct 100), height (px 2) ] ] []

    else
        case item.currentLapSectors of
            Just sectors ->
                let
                    ( s1_progress, s2_progress, s3_progress ) =
                        case item.sector of
                            Just sectorProgress ->
                                case sectorProgress.sector of
                                    S1 ->
                                        ( sectorProgress.progress, 0, 0 )

                                    S2 ->
                                        ( 100, sectorProgress.progress, 0 )

                                    S3 ->
                                        ( 100, 100, sectorProgress.progress )

                            Nothing ->
                                ( 100, 100, 100 )
                in
                div
                    [ css
                        [ width (pct 100)
                        , property "display" "grid"
                        , property "grid-template-columns" "1fr 1fr 1fr"
                        , property "column-gap" "2px"
                        ]
                    ]
                    [ sectorBar { time = sectors.sector_1, personalBest = sectors.s1_best, fastest = analysis.sector_1_fastest, progress = s1_progress }
                    , sectorBar { time = sectors.sector_2, personalBest = sectors.s2_best, fastest = analysis.sector_2_fastest, progress = s2_progress }
                    , sectorBar { time = sectors.sector_3, personalBest = sectors.s3_best, fastest = analysis.sector_3_fastest, progress = s3_progress }
                    ]

            Nothing ->
                div [ css [ width (pct 100), height (px 2) ] ] []


manufacturerLogo : Motorsport.Manufacturer.Manufacturer -> Html msg
manufacturerLogo manufacturer =
    case Motorsport.Manufacturer.toLogoUrl manufacturer of
        Just url ->
            img
                [ src url
                , css
                    [ property "max-width" "30px"
                    , property "height" "16px"
                    , property "object-fit" "contain"
                    , property "opacity" "0.9"
                    ]
                ]
                []

        Nothing ->
            div
                [ css
                    [ property "max-width" "30px"
                    , property "height" "16px"
                    ]
                ]
                []
