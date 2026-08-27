module Page.Debug exposing (Model, Msg, init, update, view)

{-| Debug page (`/debug`). Migrated from the elm-pages route to plain TEA.

@docs Model, Msg, init, update, view

-}

import Compare
import DataView
import Effect exposing (Effect)
import Html exposing (Html, div, header, input, nav, text)
import Html.Attributes as Attributes exposing (class, type_, value)
import Html.Events exposing (onClick, onInput)
import Html.Styled
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Clock as Clock
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (RatedTime)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car as Car
import Motorsport.Replay as Replay
import Motorsport.Sector as Sector
import Motorsport.Wec.Class
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
view shared { leaderboardState } =
    { title = "Wec"
    , body =
        case Shared.race shared of
            Nothing ->
                []

            Just { replay } ->
                debugView replay leaderboardState |> List.map Html.Styled.fromUnstyled
    }


debugView : Replay.Model -> Leaderboard.Model -> List (Html Msg)
debugView replay leaderboardState =
    let
        { playback, race } =
            replay

        lapCount =
            Replay.lapCount replay

        -- The whole race's records, not the clock's: this page reports what
        -- the data holds, and the slider must not change what a record means.
        bestTimes =
            BestTimes.final race.bestTimeChanges
    in
    [ header
        [ Attributes.class "sticky top-0 flex justify-between bg-[hsl(0,0%,40%)]" ]
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
            , text (Clock.getElapsed playback |> Instant.toString)
            ]
        , div []
            ([ div [] [ text "fastestLapTime: ", text (bestTimeText bestTimes.fastestLapTime) ]
             , div [] [ text "slowestLapTime: ", text (bestTimeText bestTimes.slowestLapTime) ]
             ]
                ++ (Sector.toList bestTimes.fastestSectors
                        |> List.map
                            (\( sector, fastest ) ->
                                div []
                                    [ text (Sector.toString sector ++ "_fastest: ")
                                    , text (bestTimeText fastest)
                                    ]
                            )
                   )
            )
        ]
    , let
        laps =
            race.cars
                |> List.Extra.find (\car -> car.metadata.carNumber == "2")
                |> Maybe.map (\car -> List.take lapCount car.laps)
                |> Maybe.withDefault []
      in
      DataView.view (config bestTimes) leaderboardState (List.indexedMap (lapRow bestTimes) laps)
    ]


{-| One row of this page is one lap of one car, not one car of the race. The
leaderboard columns only ask for the ratings they print, so a row carries those
and nothing of a [`Snapshot.CarAt`](Motorsport-Race-Snapshot#CarAt).
-}
type alias LapRow =
    { position : Int
    , metadata : Car.Metadata
    , currentDriver : Driver
    , lapsCompleted : Int
    , currentLapSectors : Maybe Lap.SectorTimes
    , lastLapRated : Maybe RatedTime
    , bestLapRated : Maybe RatedTime
    }


lapRow : BestTimes.Snapshot -> Int -> Lap -> LapRow
lapRow bestTimes index lap =
    let
        fastestLapTime =
            BestTimes.timeOf bestTimes.fastestLapTime
    in
    { position = index + 1

    -- The car number column is the one place a lap number can be printed, so
    -- the lap's number goes where a car's would.
    , metadata =
        { carNumber = String.fromInt lap.lap
        , drivers = [ lap.driver ]
        , class = Motorsport.Wec.Class.none
        , group = ""
        , team = ""
        , manufacturer = Manufacturer.unknown
        }
    , currentDriver = lap.driver
    , lapsCompleted = lap.lap
    , currentLapSectors = Just lap.sectors
    , lastLapRated = Performance.rateTime fastestLapTime { time = lap.time, personalBest = lap.best }
    , bestLapRated = Performance.rateTime fastestLapTime { time = lap.best, personalBest = lap.best }
    }


config : BestTimes.Snapshot -> Leaderboard.Config LapRow Msg
config bestTimes =
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
                    { getter = .lastLapRated
                    , sorter = Compare.by (.lastLapRated >> Maybe.map .time >> Maybe.withDefault 0)
                    }
               , bestTimeColumn { getter = .bestLapRated }
               ]
    }


{-| A record no lap has set has no time to print.
-}
bestTimeText : Maybe BestTimes.Holder -> String
bestTimeText =
    BestTimes.timeOf >> Maybe.map Duration.toString >> Maybe.withDefault "-"


sectorColumns : BestTimes.Snapshot -> List (DataView.Column LapRow Msg)
sectorColumns bestTimes =
    let
        fastest sector =
            BestTimes.timeOf (Sector.get sector bestTimes.fastestSectors)

        times sector =
            .currentLapSectors >> Maybe.map (Sector.get sector)
    in
    Sector.all
        |> List.concatMap
            (\sector ->
                [ sectorTimeColumn
                    { label = Sector.toString sector
                    , getter =
                        -- The table lists laps that are over, so every sector of
                        -- one is behind the car; there is no progress to report
                        -- and the column no longer asks for one.
                        times sector
                            >> Maybe.map
                                (Performance.rateTime (fastest sector)
                                    >> Performance.Completed
                                )
                    }
                , customColumn
                    { label = Sector.toString sector ++ " Best"
                    , getter = times sector >> Maybe.andThen .personalBest >> Maybe.map Duration.toString >> Maybe.withDefault ""
                    , sorter = Compare.by (times sector >> Maybe.andThen .personalBest >> Maybe.withDefault 0)
                    }
                ]
            )
