module Page.Debug exposing (Model, Msg, init, update, view)

{-| Debug page (`/debug`). Migrated from the elm-pages route to plain TEA.

@docs Model, Msg, init, update, view

-}

import Css exposing (backgroundColor, displayFlex, hsl, justifyContent, position, spaceBetween, sticky, top, zero)
import DataView
import Effect exposing (Effect)
import Html.Styled exposing (div, header, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (class, css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import List.Extra
import Motorsport.Class
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Manufacturer
import Motorsport.Replay as Replay
import Motorsport.Sector as Sector
import Motorsport.Utils exposing (compareBy)
import Motorsport.ViewModel.BestTimes exposing (BestTimes)
import Motorsport.ViewModel.Standings as Standings exposing (Entry, Standings)
import Motorsport.Widget.Leaderboard as Leaderboard exposing (bestTimeColumn, carNumberColumn_Wec, customColumn, driverAndTeamColumn_Wec, initialSort, intColumn, lastLapColumn, sectorTimeColumn)
import Shared
import Shared.Msg
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import View exposing (View)



-- MODEL


type alias Model =
    { leaderboardState : Leaderboard.Model
    , query : String
    }


init : ( Model, Effect Msg )
init =
    ( { leaderboardState = initialSort "Position"
      , query = ""
      }
    , Effect.sendSharedMsg (Shared.Msg.FetchJson_Wec { season = "2024", event = "le_mans_24h" })
    )



-- UPDATE


type Msg
    = ReplayMsg Replay.Msg
    | LeaderboardMsg Leaderboard.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ReplayMsg replayMsg ->
            ( model, Effect.sendSharedMsg (Shared.Msg.ReplayMsg replayMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { model | leaderboardState = Leaderboard.update leaderboardMsg model.leaderboardState }
            , Effect.none
            )



-- VIEW


view : Shared.Model -> Model -> View Msg
view { viewModel, replay } { leaderboardState } =
    { title = "Wec"
    , body =
        let
            { playback, race } =
                replay

            lapCount =
                Replay.lapCountAt replay
        in
        [ header
            [ css
                [ position sticky
                , top zero
                , displayFlex
                , justifyContent spaceBetween
                , backgroundColor (hsl 0 0 0.4)
                ]
            ]
            [ nav []
                [ input
                    [ type_ "range"
                    , Attributes.max <| String.fromInt race.lapTotal
                    , value (String.fromInt lapCount)
                    , onInput (String.toInt >> Maybe.withDefault 0 >> Replay.SetCount >> ReplayMsg)
                    ]
                    []
                , labeledButton []
                    [ button [ class "join-item", onClick (ReplayMsg Replay.PreviousLap) ] [ text "-" ]
                    , basicLabel [ class "join-item" ] [ text (String.fromInt lapCount) ]
                    , button [ class "join-item", onClick (ReplayMsg Replay.NextLap) ] [ text "+" ]
                    ]
                , text (Clock.getElapsed playback |> Duration.toString)
                ]
            , div []
                ([ div [] [ text "fastestLapTime: ", text (Duration.toString viewModel.bestTimes.fastestLapTime) ]
                 , div [] [ text "slowestLapTime: ", text (Duration.toString viewModel.bestTimes.slowestLapTime) ]
                 ]
                    ++ (Sector.toList viewModel.bestTimes.fastestSectors
                            |> List.map
                                (\( sector, fastest ) ->
                                    div []
                                        [ text (Sector.toString sector ++ "_fastest: ")
                                        , text (Duration.toString fastest)
                                        ]
                                )
                       )
                )
            ]
        , let
            standings =
                race.entrants
                    |> List.Extra.find (\entrant -> entrant.metadata.carNumber == "2")
                    |> Maybe.map (\entrant -> Standings.fromLaps entrant.metadata (List.take lapCount entrant.laps))
                    |> Maybe.withDefault (Standings.fromLaps { carNumber = "", drivers = [], class = Motorsport.Class.none, group = "", team = "", manufacturer = Motorsport.Manufacturer.Other } [])
          in
          DataView.view (config viewModel.bestTimes standings) leaderboardState (Standings.toList standings)
        ]
    }


config : BestTimes -> Standings -> Leaderboard.Config Entry Msg
config bestTimes standings =
    { toId = .metadata >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec { getter = .metadata }
        , driverAndTeamColumn_Wec { getter = \item -> { metadata = item.metadata, currentDriver = item.currentDriver } }
        , intColumn { label = "Lap", getter = .lapsCompleted }
        ]
            ++ sectorColumns bestTimes
            ++ [ lastLapColumn
                    { getter = identity
                    , sorter = compareBy (.lastLapRated >> Maybe.map .time >> Maybe.withDefault 0)
                    }
               , bestTimeColumn { getter = .bestLapRated }
               ]
    }


sectorColumns : BestTimes -> List (DataView.Column Entry Msg)
sectorColumns bestTimes =
    let
        fastest sector =
            Sector.get sector bestTimes.fastestSectors

        times sector =
            .currentLapSectors >> Maybe.map (Sector.get sector)
    in
    Sector.all
        |> List.concatMap
            (\sector ->
                [ sectorTimeColumn
                    { label = Sector.toString sector
                    , getter =
                        times sector
                            >> Maybe.map
                                (\{ time, personalBest } ->
                                    { time = time
                                    , personalBest = personalBest
                                    , fastest = fastest sector
                                    , progress = 1
                                    }
                                )
                    }
                , customColumn
                    { label = Sector.toString sector ++ " Best"
                    , getter = times sector >> Maybe.map (.personalBest >> Duration.toString) >> Maybe.withDefault ""
                    , sorter = compareBy (times sector >> Maybe.map .personalBest >> Maybe.withDefault 0)
                    }
                ]
            )
