module Main exposing (main)

import Browser exposing (Document)
import Browser.Navigation as Nav exposing (Key)
import Data.Wec.Car exposing (Car)
import Effect exposing (Effect)
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
    , page : PageModel
    , cars : List Car
    }


type PageModel
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
    , page = TopModel
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
                let
                    ( pageModel, effect ) =
                        case page of
                            NotFound ->
                                ( None, Effect.none )

                            Top ->
                                ( TopModel, Effect.none )

                            GapChart ->
                                GapChart.init
                                    |> Tuple.mapSecond Effect.fromCmd
                                    |> updateWith GapChartModel GapChartMsg

                            LapTimeChart ->
                                LapTimeChart.init
                                    |> Tuple.mapSecond Effect.fromCmd
                                    |> updateWith LapTimeChartModel LapTimeChartMsg

                            LapTimeChartsByDriver ->
                                LapTimeChartsByDriver.init
                                    |> Tuple.mapSecond Effect.fromCmd
                                    |> updateWith LapTimeChartsByDriverModel LapTimeChartsByDriverMsg

                            Leaderboard ->
                                Leaderboard.init
                                    |> Tuple.mapSecond Effect.fromCmd
                                    |> updateWith LeaderboardModel LeaderboardMsg

                            LeaderboardWec ->
                                LeaderboardWec.init
                                    |> Tuple.mapSecond Effect.fromCmd
                                    |> updateWith LeaderboardWecModel LeaderboardWecMsg

                            Wec ->
                                Wec.init
                                    |> Tuple.mapSecond Effect.fromCmd
                                    |> updateWith WecModel WecMsg
                in
                ( { model | page = pageModel }
                , Effect.toCmd Page effect
                )
           )



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | Page PageMsg


type PageMsg
    = GapChartMsg GapChart.Msg
    | LapTimeChartMsg LapTimeChart.Msg
    | LapTimeChartsByDriverMsg LapTimeChartsByDriver.Msg
    | LeaderboardMsg Leaderboard.Msg
    | LeaderboardWecMsg LeaderboardWec.Msg
    | WecMsg Wec.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            routing url model

        Page pageMsg ->
            let
                ( pageModel, effect ) =
                    case ( model.page, pageMsg ) of
                        ( GapChartModel pageModel_, GapChartMsg pageMsg_ ) ->
                            GapChart.update pageMsg_ pageModel_
                                |> Tuple.mapSecond Effect.fromCmd
                                |> updateWith GapChartModel GapChartMsg

                        ( LapTimeChartModel pageModel_, LapTimeChartMsg pageMsg_ ) ->
                            LapTimeChart.update pageMsg_ pageModel_
                                |> Tuple.mapSecond Effect.fromCmd
                                |> updateWith LapTimeChartModel LapTimeChartMsg

                        ( LapTimeChartsByDriverModel pageModel_, LapTimeChartsByDriverMsg pageMsg_ ) ->
                            LapTimeChartsByDriver.update pageMsg_ pageModel_
                                |> Tuple.mapSecond Effect.fromCmd
                                |> updateWith LapTimeChartsByDriverModel LapTimeChartsByDriverMsg

                        ( LeaderboardModel pageModel_, LeaderboardMsg pageMsg_ ) ->
                            Leaderboard.update pageMsg_ pageModel_
                                |> Tuple.mapSecond Effect.fromCmd
                                |> updateWith LeaderboardModel LeaderboardMsg

                        ( LeaderboardWecModel pageModel_, LeaderboardWecMsg pageMsg_ ) ->
                            LeaderboardWec.update pageMsg_ pageModel_
                                |> Tuple.mapSecond Effect.fromCmd
                                |> updateWith LeaderboardWecModel LeaderboardWecMsg

                        ( WecModel pageModel_, WecMsg pageMsg_ ) ->
                            Wec.update pageMsg_ pageModel_
                                |> Tuple.mapSecond Effect.fromCmd
                                |> updateWith WecModel WecMsg

                        _ ->
                            ( None, Effect.none )
            in
            ( { model | page = pageModel }
            , Effect.toCmd Page effect
            )


updateWith : (pageModel -> PageModel) -> (pageMsg_ -> PageMsg) -> ( pageModel, Effect pageMsg_ ) -> ( PageModel, Effect PageMsg )
updateWith toModel toMsg ( pageModel, pageEffect ) =
    ( toModel pageModel, Effect.map toMsg pageEffect )



-- VIEW


view : Model -> Document Msg
view model =
    { title = "Race Analysis"
    , body =
        List.map toUnstyled <|
            case model.page of
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

                GapChartModel pageModel ->
                    GapChart.view pageModel
                        |> List.map (Html.map (GapChartMsg >> Page))

                LapTimeChartModel pageModel ->
                    LapTimeChart.view pageModel
                        |> List.map (Html.map (LapTimeChartMsg >> Page))

                LapTimeChartsByDriverModel pageModel ->
                    LapTimeChartsByDriver.view pageModel
                        |> List.map (Html.map (LapTimeChartsByDriverMsg >> Page))

                LeaderboardModel pageModel ->
                    Leaderboard.view pageModel
                        |> List.map (Html.map (LeaderboardMsg >> Page))

                LeaderboardWecModel pageModel ->
                    LeaderboardWec.view pageModel
                        |> List.map (Html.map (LeaderboardWecMsg >> Page))

                WecModel pageModel ->
                    Wec.view pageModel
                        |> List.map (Html.map (WecMsg >> Page))
    }
