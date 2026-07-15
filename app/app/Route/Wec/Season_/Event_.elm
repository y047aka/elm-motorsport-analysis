module Route.Wec.Season_.Event_ exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Browser.Events
import Css exposing (..)
import Data.Series.EventSummary exposing (EventSummary)
import DataView
import DataView.Options exposing (PaginationOption(..), SelectingOption(..))
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled exposing (Html, button, div, main_, nav, text)
import Html.Styled.Attributes as Attributes exposing (attribute, css)
import Html.Styled.Events exposing (onClick)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock exposing (State(..))
import Motorsport.Leaderboard as Leaderboard exposing (initialSort)
import Motorsport.RaceControl as RaceControl
import Motorsport.ViewModel.LapHistory exposing (LapHistory)
import Motorsport.ViewModel.Standings exposing (Standings)
import Motorsport.Widget.Compare as CompareWidget
import Motorsport.Widget.LiveStandings as LiveStandingsWidget
import Motorsport.Widget.SelectedCarsStrip as SelectedCarsStrip
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import Task
import Time
import UrlPath exposing (UrlPath)
import View exposing (View)
import View.CarDetailPopover as CarDetailPopover
import View.PlaybackControls as PlaybackControls
import View.RaceEvents as RaceEvents


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
    , stripOffset : Int
    , detailCarNumbers : List String
    , detailChart : CompareWidget.Chart
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
      , stripOffset = 0
      , detailCarNumbers = []
      , detailChart = CompareWidget.GapChart
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
    | StripScrollTo Int
    | ShowCarDetail String
    | ToggleDetailCar String
    | SelectDetailChart CompareWidget.Chart


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

        StripScrollTo offset ->
            ( { m | stripOffset = max 0 offset }, Effect.none, Nothing )

        ShowCarDetail carNumber ->
            -- Opening the modal from a standings row click; reset the selection to this single car.
            ( { m | detailCarNumbers = [ carNumber ] }, Effect.none, Nothing )

        ToggleDetailCar carNumber ->
            -- In-modal selector; toggle selection up to a maximum of 3 cars.
            let
                next =
                    if List.member carNumber m.detailCarNumbers then
                        List.filter ((/=) carNumber) m.detailCarNumbers

                    else
                        List.take 3 (m.detailCarNumbers ++ [ carNumber ])
            in
            ( { m | detailCarNumbers = next }, Effect.none, Nothing )

        SelectDetailChart chart ->
            ( { m | detailChart = chart }, Effect.none, Nothing )



-- SUBSCRIPTIONS


subscriptions : RouteParams -> UrlPath -> Shared.Model -> Model -> Sub Msg
subscriptions routeParams path shared model =
    case shared.raceControl.clock.state of
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
view app { eventSummary, analysis, raceControl, standings, lapHistory } m =
    View.map PagesMsg.fromMsg
        { title = "Wec"
        , body =
            [ main_
                [ attribute "data-theme" "forest"
                , css
                    [ height (pct 100)
                    , property "display" "grid"
                    , property "grid-template-rows" "auto 1fr"
                    ]
                ]
                [ navigation eventSummary raceControl m.mode
                , case m.mode of
                    Tracker ->
                        trackerView eventSummary analysis { standings = standings, history = lapHistory } m

                    Events ->
                        RaceEvents.view EventsMsg m.eventsState raceControl
                ]
            ]
        }


trackerView : EventSummary -> Analysis -> { standings : Standings, history : LapHistory } -> Model -> Html Msg
trackerView eventSummary analysis { standings, history } m =
    div
        [ css
            [ property "grid-row" "2"
            , property "height" "100%"
            , overflowY hidden
            , padding4 (px 0) (px 10) (px 10) (px 10)
            , property "display" "grid"
            , property "grid-template-columns" "300px 1fr 300px"
            , property "grid-template-rows" "minmax(0, 1fr) auto"
            , property "row-gap" "10px"
            , property "column-gap" "10px"
            ]
        ]
        [ div
            [ css
                [ property "grid-column" "1"
                , property "height" "100%"
                , overflowY hidden
                ]
            ]
            [ LiveStandingsWidget.view
                { standings = standings

                -- クロージャではなくコンストラクタを直接渡す（行の Lazy を効かせるため）
                , onSelectCar = ShowCarDetail
                , popoverTarget = CarDetailPopover.popoverId
                }
            ]
        , div
            [ Attributes.class "card bg-base-200"
            , css [ property "grid-column" "2" ]
            ]
            [ div [ Attributes.class "card-body p-3" ]
                [ div
                    [ css
                        [ property "height" "100%"
                        , property "display" "grid"
                        , property "place-items" "center"
                        ]
                    ]
                    [ TrackerChart.view
                        { season = eventSummary.season, eventName = eventSummary.name }
                        analysis
                        standings
                    ]
                ]
            ]
        , div
            [ Attributes.class "card bg-base-200"
            , css [ property "grid-column" "3" ]
            ]
            []
        , div [ css [ property "grid-column" "1 / -1" ] ]
            [ SelectedCarsStrip.view
                { offset = m.stripOffset
                , onScrollTo = StripScrollTo
                }
                { standings = standings, history = history }
            ]
        , CarDetailPopover.view
            { activeChart = m.detailChart
            , onToggleCar = ToggleDetailCar
            , onSelectChart = SelectDetailChart
            }
            { standings = standings, history = history }
            m.detailCarNumbers
        ]


navigation : EventSummary -> RaceControl.Model -> Mode -> Html Msg
navigation eventSummary raceControl currentMode =
    let
        headerTitle =
            eventSummary.name ++ " (" ++ String.fromInt eventSummary.season ++ ")"
    in
    nav
        [ Attributes.class "p-3"
        , css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr auto"
            , alignItems center
            , property "column-gap" "40px"
            ]
        ]
        [ div [ Attributes.class "text-sm whitespace-nowrap" ] [ text headerTitle ]
        , PlaybackControls.view
            { raceControl = raceControl
            , onStart = StartRace
            , onPause = PauseRace
            , toRaceControlMsg = RaceControlMsg
            }
        , viewModeSelector currentMode
        ]


viewModeSelector : Mode -> Html Msg
viewModeSelector currentMode =
    div [ Attributes.class "join" ]
        [ modeButton "Tracker" Tracker (currentMode == Tracker)
        , modeButton "Events" Events (currentMode == Events)
        ]


modeButton : String -> Mode -> Bool -> Html Msg
modeButton label mode isActive =
    joinButton label isActive (ModeChange mode)


joinButton : String -> Bool -> Msg -> Html Msg
joinButton label isActive msg =
    button
        [ onClick msg
        , Attributes.class
            ("join-item btn btn-sm btn-soft"
                ++ (if isActive then
                        " btn-active"

                    else
                        ""
                   )
            )
        ]
        [ text label ]
