module Main exposing (main)

import Browser exposing (Document)
import Browser.Navigation as Nav exposing (Key)
import Data.Car exposing (Car)
import Html.Styled as Html exposing (a, br, text, toUnstyled)
import Html.Styled.Attributes exposing (href)
import List.Extra as List
import Page.GapChart as GapChart
import Page.LapTimeChart as LapTimeChart
import Page.LapTimeChartsByDriver as LapTimeChartsByDriver
import Page.Leaderboard as Leaderboard
import Page.LeaderboardWec as LeaderboardWec
import Page.Wec as Wec
import Url exposing (Url)
import Url.Parser exposing (Parser, s)



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }



-- MODEL


type alias Model =
    { key : Key
    , subModel : SubModel
    , cars : List Car
    }


type SubModel
    = None
    | TopModel
    | GapChartModel GapChart.Model
    | LapTimeChartModel LapTimeChart.Model
    | LapTimeChartsByDriverModel LapTimeChartsByDriver.Model
    | LeaderboardModel Leaderboard.Model
    | LeaderboardWecModel LeaderboardWec.Model
    | WecModel Wec.Model


init : () -> Url -> Key -> ( Model, Cmd Msg )
init _ url key =
    { key = key
    , subModel = TopModel
    , cars = []
    }
        |> routing url



-- ROUTER


type Page
    = NotFound
    | Top
    | GapChart
    | LapTimeChart
    | LapTimeChartsByDriver
    | Leaderboard
    | LeaderboardWec
    | Wec


parser : Parser (Page -> a) a
parser =
    Url.Parser.oneOf
        [ Url.Parser.map Top Url.Parser.top
        , Url.Parser.map GapChart (s "gap-chart")
        , Url.Parser.map LapTimeChart (s "lapTime-chart")
        , Url.Parser.map LapTimeChartsByDriver (s "lapTime-charts-by-driver")
        , Url.Parser.map Leaderboard (s "leaderboard")
        , Url.Parser.map LeaderboardWec (s "leaderboard-wec")
        , Url.Parser.map Wec (s "wec")
        ]


routing : Url -> Model -> ( Model, Cmd Msg )
routing url model =
    Url.Parser.parse parser url
        |> Maybe.withDefault NotFound
        |> (\page ->
                case page of
                    NotFound ->
                        ( { model | subModel = None }, Cmd.none )

                    Top ->
                        ( { model | subModel = TopModel }, Cmd.none )

                    GapChart ->
                        GapChart.init
                            |> updateWith GapChartModel GapChartMsg model

                    LapTimeChart ->
                        LapTimeChart.init
                            |> updateWith LapTimeChartModel LapTimeChartMsg model

                    LapTimeChartsByDriver ->
                        LapTimeChartsByDriver.init
                            |> updateWith LapTimeChartsByDriverModel LapTimeChartsByDriverMsg model

                    Leaderboard ->
                        Leaderboard.init
                            |> updateWith LeaderboardModel LeaderboardMsg model

                    LeaderboardWec ->
                        LeaderboardWec.init
                            |> updateWith LeaderboardWecModel LeaderboardWecMsg model

                    Wec ->
                        Wec.init
                            |> updateWith WecModel WecMsg model
           )



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | GapChartMsg GapChart.Msg
    | LapTimeChartMsg LapTimeChart.Msg
    | LapTimeChartsByDriverMsg LapTimeChartsByDriver.Msg
    | LeaderboardMsg Leaderboard.Msg
    | LeaderboardWecMsg LeaderboardWec.Msg
    | WecMsg Wec.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( model.subModel, msg ) of
        ( _, UrlRequested urlRequest ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        ( _, UrlChanged url ) ->
            routing url model

        ( GapChartModel subModel, GapChartMsg submsg ) ->
            GapChart.update submsg subModel
                |> updateWith GapChartModel GapChartMsg model

        ( LapTimeChartModel subModel, LapTimeChartMsg submsg ) ->
            LapTimeChart.update submsg subModel
                |> updateWith LapTimeChartModel LapTimeChartMsg model

        ( LapTimeChartsByDriverModel subModel, LapTimeChartsByDriverMsg submsg ) ->
            LapTimeChartsByDriver.update submsg subModel
                |> updateWith LapTimeChartsByDriverModel LapTimeChartsByDriverMsg model

        ( LeaderboardModel subModel, LeaderboardMsg submsg ) ->
            Leaderboard.update submsg subModel
                |> updateWith LeaderboardModel LeaderboardMsg model

        ( LeaderboardWecModel subModel, LeaderboardWecMsg submsg ) ->
            LeaderboardWec.update submsg subModel
                |> updateWith LeaderboardWecModel LeaderboardWecMsg model

        ( WecModel subModel, WecMsg submsg ) ->
            Wec.update submsg subModel
                |> updateWith WecModel WecMsg model

        _ ->
            ( model, Cmd.none )


updateWith : (subModel -> SubModel) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( { model | subModel = toModel subModel }
    , Cmd.map toMsg subCmd
    )



-- VIEW


view : Model -> Document Msg
view model =
    { title = "Race Analysis"
    , body =
        List.map toUnstyled <|
            case model.subModel of
                None ->
                    []

                TopModel ->
                    [ a [ href "/gap-chart" ] [ text "Gap Chart" ]
                    , br [] []
                    , a [ href "/lapTime-chart" ] [ text "LapTime Chart" ]
                    , br [] []
                    , a [ href "/lapTime-charts-by-driver" ] [ text "LapTime Charts By Driver" ]
                    , br [] []
                    , a [ href "/leaderboard" ] [ text "Leader Board" ]
                    , br [] []
                    , a [ href "/leaderboard-wec" ] [ text "Leader Board WEC" ]
                    , br [] []
                    , a [ href "/wec" ] [ text "Wec" ]
                    ]

                GapChartModel subModel ->
                    GapChart.view subModel

                LapTimeChartModel subModel ->
                    LapTimeChart.view subModel

                LapTimeChartsByDriverModel subModel ->
                    LapTimeChartsByDriver.view subModel

                LeaderboardModel subModel ->
                    Leaderboard.view subModel
                        |> List.map (Html.map LeaderboardMsg)

                LeaderboardWecModel subModel ->
                    LeaderboardWec.view subModel
                        |> List.map (Html.map LeaderboardWecMsg)

                WecModel subModel ->
                    Wec.view subModel
    }
