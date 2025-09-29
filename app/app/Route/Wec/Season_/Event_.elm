module Route.Wec.Season_.Event_ exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Browser.Events
import Css exposing (alignItems, center, displayFlex, height, hidden, overflowY, padding2, pct, property, px, right, scroll, textAlign, zero)
import DataView
import DataView.Options exposing (PaginationOption(..), SelectingOption(..))
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled as Html exposing (Html, button, div, input, li, main_, nav, text, ul)
import Html.Styled.Attributes as Attributes exposing (attribute, class, css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Html.Styled.Lazy as Lazy
import List.Extra
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock exposing (Model(..))
import Motorsport.Duration as Duration
import Motorsport.Leaderboard as Leaderboard exposing (initialSort)
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModel)
import Motorsport.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Utils exposing (compareBy)
import Motorsport.Widget.CloseBattles as CloseBattlesWidget
import Motorsport.Widget.Compare as CompareWidget
import Motorsport.Widget.LiveStandings as LiveStandingsWidget
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import SortedList
import String exposing (dropRight)
import Task
import Time
import UI.HalfModal as HalfModal
import UrlPath exposing (UrlPath)
import View exposing (View)


type alias RouteParams =
    { season : String, event : String }


route : StatefulRoute RouteParams Data ActionData Model Msg
route =
    RouteBuilder.preRender
        { head = \_ -> []
        , pages = pages
        , data = data
        }
        |> RouteBuilder.buildWithSharedState
            { init = init
            , update = update
            , subscriptions = subscriptions
            , view = view
            }


pages : BackendTask FatalError (List RouteParams)
pages =
    BackendTask.succeed
        [ { season = "2024", event = "le_mans_24h" }
        , { season = "2024", event = "fuji_6h" }
        , { season = "2024", event = "bahrain_8h" }
        , { season = "2025", event = "qatar_1812km" }
        , { season = "2025", event = "imola_6h" }
        , { season = "2025", event = "spa_6h" }
        , { season = "2025", event = "le_mans_24h" }
        , { season = "2025", event = "sao_paulo_6h" }
        , { season = "2025", event = "cota_6h" }
        , { season = "2025", event = "fuji_6h" }
        ]



-- MODEL


type alias Model =
    { mode : Mode
    , leaderboardState : Leaderboard.Model
    , eventsState : DataView.Model
    , query : String
    , isLeaderboardModalOpen : Bool
    , selectedCar : Maybe String
    , compareWith : Maybe String
    }


type Mode
    = Tracker
    | Events


init :
    App Data ActionData RouteParams
    -> Shared.Model
    -> ( Model, Effect Msg )
init app shared =
    ( { mode = Tracker
      , leaderboardState = initialSort "Position"
      , eventsState =
            DataView.init "Time"
                (DataView.Options.defaultOptions
                    |> (\options_ ->
                            { options_
                                | selecting = NoSelecting
                                , pagination = NoPagination
                            }
                       )
                )
      , query = ""
      , isLeaderboardModalOpen = False
      , selectedCar = Nothing
      , compareWith = Nothing
      }
    , Effect.fromCmd
        (Task.succeed (Shared.FetchJson_Wec { season = app.routeParams.season, event = app.routeParams.event })
            |> Task.perform SharedMsg
        )
    )



-- UPDATE


type Msg
    = SharedMsg Shared.Msg
    | StartRace
    | PauseRace
    | ModeChange Mode
    | RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg
    | EventsMsg DataView.Msg
    | ToggleLeaderboardModal
    | CarSelected String
    | SwapCompare
    | ClearCompare
    | ClearSelectedCar


update :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Msg
    -> Model
    -> ( Model, Effect Msg, Maybe Shared.Msg )
update app shared msg m =
    case msg of
        SharedMsg sharedMsg ->
            ( m, Effect.none, Just sharedMsg )

        StartRace ->
            ( m, Task.perform (RaceControl.Start >> RaceControlMsg) Time.now |> Effect.fromCmd, Nothing )

        PauseRace ->
            ( m, Task.perform (RaceControl.Pause >> RaceControlMsg) Time.now |> Effect.fromCmd, Nothing )

        ModeChange mode ->
            ( { m | mode = mode }, Effect.none, Nothing )

        RaceControlMsg raceControlMsg ->
            ( m, Effect.none, Just (Shared.RaceControlMsg raceControlMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            , Nothing
            )

        EventsMsg eventsMsg ->
            ( { m | eventsState = DataView.update eventsMsg m.eventsState }
            , Effect.none
            , Nothing
            )

        ToggleLeaderboardModal ->
            ( { m | isLeaderboardModalOpen = not m.isLeaderboardModalOpen }
            , Effect.none
            , Nothing
            )

        CarSelected carNumber ->
            let
                nextModel =
                    case ( m.selectedCar, m.compareWith ) of
                        ( Nothing, _ ) ->
                            { m | selectedCar = Just carNumber }

                        ( Just a, Nothing ) ->
                            if a /= carNumber then
                                { m | compareWith = Just carNumber }

                            else
                                m

                        ( Just a, Just _ ) ->
                            if a /= carNumber then
                                { m | compareWith = Just carNumber }

                            else
                                m
            in
            ( nextModel
            , Effect.none
            , Nothing
            )

        SwapCompare ->
            ( case ( m.selectedCar, m.compareWith ) of
                ( Just a, Just b ) ->
                    { m | selectedCar = Just b, compareWith = Just a }

                _ ->
                    m
            , Effect.none
            , Nothing
            )

        ClearCompare ->
            ( { m | compareWith = Nothing }
            , Effect.none
            , Nothing
            )

        ClearSelectedCar ->
            case ( m.selectedCar, m.compareWith ) of
                ( Just _, Just compareCar ) ->
                    ( { m | selectedCar = Just compareCar, compareWith = Nothing }
                    , Effect.none
                    , Nothing
                    )

                ( Just _, Nothing ) ->
                    ( { m | selectedCar = Nothing }
                    , Effect.none
                    , Nothing
                    )

                ( Nothing, Just compareCar ) ->
                    ( { m | selectedCar = Just compareCar, compareWith = Nothing }
                    , Effect.none
                    , Nothing
                    )

                _ ->
                    ( m, Effect.none, Nothing )



-- SUBSCRIPTIONS


subscriptions : RouteParams -> UrlPath -> Shared.Model -> Model -> Sub Msg
subscriptions routeParams path shared model =
    case shared.raceControl.clock of
        Started _ _ ->
            Browser.Events.onAnimationFrame (RaceControl.Tick >> RaceControlMsg)

        _ ->
            Sub.none



-- DATA


type alias Data =
    {}


type alias ActionData =
    {}


data : RouteParams -> BackendTask FatalError Data
data routeParams =
    BackendTask.succeed {}



-- VIEW


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view app ({ eventSummary, analysis, raceControl } as shared) m =
    View.map PagesMsg.fromMsg
        { title = "Wec"
        , body =
            [ Html.node "style"
                []
                [ text """
                    @keyframes slideUp {
                        from {
                            transform: translateY(100%);
                        }
                        to {
                            transform: translateY(0);
                        }
                    }
                """ ]
            , main_
                [ attribute "data-theme" "dark"
                , css
                    [ height (pct 100)
                    , property "display" "grid"
                    , property "grid-template-rows" "auto auto 1fr"
                    ]
                ]
                [ navigation shared.raceControl
                , let
                    { mode, eventsState, isLeaderboardModalOpen, selectedCar } =
                        m

                    viewModel =
                        ViewModel.init raceControl

                    viewModelItems =
                        viewModel.items
                            |> SortedList.toList

                    findByCarNumber carNo =
                        viewModelItems
                            |> List.Extra.find (\item -> item.metadata.carNumber == carNo)

                    selectedCarItem =
                        case selectedCar |> Maybe.andThen findByCarNumber of
                            Just item ->
                                Just item

                            Nothing ->
                                List.head viewModelItems

                    fallbackCompareItem =
                        case selectedCarItem of
                            Just selectedItem ->
                                viewModelItems
                                    |> List.filter (\item -> item.metadata.carNumber /= selectedItem.metadata.carNumber)
                                    |> List.head
                                    |> Maybe.withDefault selectedItem
                                    |> Just

                            Nothing ->
                                case viewModelItems of
                                    _ :: second :: _ ->
                                        Just second

                                    first :: [] ->
                                        Just first

                                    [] ->
                                        Nothing

                    compareItem =
                        case m.compareWith |> Maybe.andThen findByCarNumber of
                            Just item ->
                                Just item

                            Nothing ->
                                fallbackCompareItem
                  in
                  case mode of
                    Tracker ->
                        div
                            [ css
                                [ height (pct 100)
                                , overflowY hidden
                                , property "position" "relative"
                                ]
                            ]
                            [ div
                                [ css
                                    [ height (pct 100)
                                    , property "display" "grid"
                                    , property "grid-template-columns" "370px 1fr 370px"
                                    , property "grid-template-rows" "1fr 400px"
                                    ]
                                ]
                                [ div
                                    [ css
                                        [ height (pct 100)
                                        , overflowY scroll
                                        , padding2 zero (px 10)
                                        ]
                                    ]
                                    [ LiveStandingsWidget.view
                                        { eventSummary = eventSummary
                                        , viewModel = viewModel
                                        , onSelectCar = \item -> CarSelected item.metadata.carNumber
                                        }
                                    ]
                                , div [ css [ property "display" "grid", property "place-items" "center" ] ]
                                    [ case ( eventSummary.season, eventSummary.name ) of
                                        ( 2025, "24 Hours of Le Mans" ) ->
                                            TrackerChart.viewWithMiniSectors analysis viewModel

                                        _ ->
                                            TrackerChart.view analysis viewModel
                                    ]
                                , div
                                    [ css
                                        [ height (pct 100)
                                        , overflowY scroll
                                        , padding2 zero (px 10)
                                        , property "display" "flex"
                                        , property "flex-direction" "column"
                                        ]
                                    ]
                                    [ analysisWidgets viewModel ]
                                , div
                                    [ css
                                        [ property "grid-column" "1 / -1"
                                        , property "position" "relative"
                                        , height (pct 100)
                                        ]
                                    ]
                                    [ HalfModal.view
                                        { isOpen = isLeaderboardModalOpen
                                        , onToggle = ToggleLeaderboardModal
                                        , children =
                                            [ case ( selectedCarItem, compareItem ) of
                                                ( Just a, Just b ) ->
                                                    let
                                                        compareProps =
                                                            { eventSummary = eventSummary
                                                            , viewModel = viewModel
                                                            , clock = raceControl.clock
                                                            , analysis = analysis
                                                            , carA = a
                                                            , carB = b
                                                            , actions =
                                                                { swap = SwapCompare
                                                                , clearA = ClearSelectedCar
                                                                , clearB = ClearCompare
                                                                }
                                                            }
                                                    in
                                                    Lazy.lazy CompareWidget.view compareProps

                                                _ ->
                                                    div [] [ text "車両データがありません" ]
                                            ]
                                        }
                                    ]
                                ]
                            ]

                    Events ->
                        eventsView eventsState raceControl
                ]
            ]
        }


navigation : RaceControl.Model -> Html Msg
navigation raceControl =
    nav
        [ class "navbar" ]
        [ div [ class "navbar-start" ]
            [ ul [ class "menu menu-horizontal px-1" ] <|
                (case raceControl.clock of
                    Initial ->
                        li [] [ button [ class "btn", onClick StartRace ] [ text "Start" ] ]

                    Started _ _ ->
                        li [] [ button [ class "btn", onClick PauseRace ] [ text "Pause" ] ]

                    Paused _ ->
                        li [] [ button [ class "btn", onClick StartRace ] [ text "Resume" ] ]

                    Finished ->
                        text ""
                )
                    :: (case raceControl.clock of
                            Started _ _ ->
                                []

                            _ ->
                                [ li [] [ button [ class "btn", onClick (RaceControlMsg RaceControl.Add10seconds) ] [ text "+10s" ] ]
                                , li [] [ button [ class "btn", onClick (RaceControlMsg RaceControl.NextLap) ] [ text "+1 Lap" ] ]
                                ]
                       )
            ]
        , div [ class "navbar-center" ] [ statusBar raceControl ]
        , div [ class "navbar-end" ]
            [ ul [ class "menu menu-horizontal px-1" ]
                [ li [] [ button [ class "btn", onClick (ModeChange Tracker) ] [ text "Tracker" ] ]
                , li [] [ button [ class "btn", onClick (ModeChange Events) ] [ text "Events" ] ]
                ]
            ]
        ]


statusBar : RaceControl.Model -> Html.Html Msg
statusBar { clock, lapTotal, lapCount, timeLimit } =
    let
        elapsed =
            Clock.getElapsed clock

        remaining =
            timeLimit - elapsed
    in
    div [ css [ displayFlex, alignItems center, property "column-gap" "10px" ] ]
        [ div []
            [ div [] [ text "Elapsed" ]
            , div [] [ text (Clock.toString clock) ]
            ]
        , input
            [ type_ "range"
            , Attributes.max <| String.fromInt lapTotal
            , value (String.fromInt lapCount)
            , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
            ]
            []
        , div [ css [ textAlign right ] ]
            [ div [] [ text "Remaining" ]
            , div [] [ text (Duration.toString remaining |> dropRight 4) ]
            ]
        ]


analysisWidgets : ViewModel -> Html Msg
analysisWidgets viewModel =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-rows" "auto auto auto auto"
            , property "row-gap" "10px"
            ]
        ]
        [ CloseBattlesWidget.view viewModel ]


eventsView : DataView.Model -> RaceControl.Model -> Html Msg
eventsView eventsState raceControl =
    let
        currentElapsed =
            Clock.getElapsed raceControl.clock

        occurredEvents =
            raceControl.timelineEvents
                |> List.filter (\event -> currentElapsed >= event.eventTime)
                |> List.sortBy .eventTime
    in
    div []
        [ Html.h2 [] [ text "Race Events" ]
        , DataView.view eventsConfig eventsState occurredEvents
        ]


eventsConfig : DataView.Config TimelineEvent Msg
eventsConfig =
    { toId = .eventTime >> Duration.toString
    , toMsg = EventsMsg
    , columns =
        [ DataView.customColumn
            { label = "Time"
            , getter = .eventTime >> Duration.toString
            , sorter = compareBy .eventTime
            }
        , DataView.stringColumn
            { label = "Car"
            , getter =
                \event ->
                    case event.eventType of
                        CarEvent carNumber _ ->
                            carNumber

                        _ ->
                            ""
            }
        , DataView.stringColumn
            { label = "Event"
            , getter = .eventType >> eventTypeToString
            }
        ]
    }


eventTypeToString : EventType -> String
eventTypeToString eventType =
    case eventType of
        RaceStart ->
            "Race Started"

        CarEvent _ (Start _) ->
            "Start"

        CarEvent _ (LapCompleted lap _) ->
            "Lap " ++ String.fromInt lap ++ " Completed"

        CarEvent _ Retirement ->
            "Retirement"

        CarEvent _ Checkered ->
            "Checkered Flag"
