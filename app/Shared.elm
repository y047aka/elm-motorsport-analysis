module Shared exposing (Data, Model, Msg(..), template)

import BackendTask exposing (BackendTask)
import Css exposing (..)
import Css.Global exposing (global)
import Csv.Decode as Decode exposing (Decoder, FieldNames(..))
import Data.F1.Decoder as F1
import Data.F1.Preprocess as Preprocess_F1
import Data.Wec.Decoder as Wec
import Data.Wec.Preprocess as Preprocess_Wec
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html
import Html.Styled exposing (main_)
import Http exposing (Error(..), Expect, Response(..))
import Motorsport.Analysis as Analysis exposing (Analysis)
import Motorsport.RaceControl as RaceControl
import Pages.Flags
import Pages.PageUrl exposing (PageUrl)
import Route exposing (Route)
import SharedTemplate exposing (SharedTemplate)
import UrlPath exposing (UrlPath)
import View exposing (View)


template : SharedTemplate Msg Model Data msg
template =
    { init = init
    , update = update
    , view = view
    , data = data
    , subscriptions = subscriptions
    , onPageChange = Nothing
    }


type alias Data =
    ()



-- INIT


type alias Model =
    { raceControl_F1 : RaceControl.Model
    , raceControl_Wec : RaceControl.Model
    , analysis : Analysis
    }


init :
    Pages.Flags.Flags
    ->
        Maybe
            { path :
                { path : UrlPath
                , query : Maybe String
                , fragment : Maybe String
                }
            , metadata : route
            , pageUrl : Maybe PageUrl
            }
    -> ( Model, Effect Msg )
init flags maybePagePath =
    ( { raceControl_F1 = RaceControl.empty
      , raceControl_Wec = RaceControl.empty
      , analysis = Analysis.finished RaceControl.empty
      }
    , Effect.batch
        [ Effect.fromCmd <|
            Http.get
                { url = "/static/lapTimes.json"
                , expect = Http.expectJson JsonLoaded F1.decoder
                }
        , Effect.fromCmd <|
            Http.get
                { url = "/static/23_Analysis_Race_Hour 24.csv"
                , expect = expectCsv CsvLoaded Wec.lapDecoder
                }
        ]
    )



-- UPDATE


type Msg
    = FetchJson String
    | JsonLoaded (Result Http.Error (List F1.Car))
    | FetchCsv String
    | CsvLoaded (Result Http.Error (List Wec.Lap))
    | RaceControlMsg_F1 RaceControl.Msg
    | RaceControlMsg_Wec RaceControl.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        FetchJson url ->
            ( m
            , Effect.fromCmd <|
                Http.get
                    { url = url
                    , expect = Http.expectJson JsonLoaded F1.decoder
                    }
            )

        JsonLoaded (Ok decoded) ->
            let
                rcNew =
                    RaceControl.init (Preprocess_F1.preprocess decoded)
            in
            ( { m
                | raceControl_F1 = rcNew
                , analysis = Analysis.finished rcNew
              }
            , Effect.none
            )

        JsonLoaded (Err _) ->
            ( m, Effect.none )

        FetchCsv url ->
            ( m
            , Effect.fromCmd <|
                Http.get
                    { url = url
                    , expect = expectCsv CsvLoaded Wec.lapDecoder
                    }
            )

        CsvLoaded (Ok decoded) ->
            let
                rcNew =
                    RaceControl.init (Preprocess_Wec.preprocess decoded)
            in
            ( { m
                | raceControl_Wec = rcNew
                , analysis = Analysis.finished rcNew
              }
            , Effect.none
            )

        CsvLoaded (Err _) ->
            ( m, Effect.none )

        RaceControlMsg_F1 raceControlMsg ->
            let
                rcNew =
                    RaceControl.update raceControlMsg m.raceControl_F1
            in
            ( { m
                | raceControl_F1 = rcNew
                , analysis = Analysis.fromRaceControl rcNew
              }
            , Effect.none
            )

        RaceControlMsg_Wec raceControlMsg ->
            let
                rcNew =
                    RaceControl.update raceControlMsg m.raceControl_Wec
            in
            ( { m
                | raceControl_Wec = rcNew
                , analysis = Analysis.fromRaceControl rcNew
              }
            , Effect.none
            )


expectCsv : (Result Http.Error (List a) -> msg) -> Decoder a -> Expect msg
expectCsv toMsg decoder_ =
    let
        resolve : (body -> Result String (List a)) -> Response body -> Result Error (List a)
        resolve toResult response =
            case response of
                BadUrl_ url ->
                    Err (BadUrl url)

                Timeout_ ->
                    Err Timeout

                NetworkError_ ->
                    Err NetworkError

                BadStatus_ metadata _ ->
                    Err (BadStatus metadata.statusCode)

                GoodStatus_ _ body ->
                    Result.mapError BadBody (toResult body)
    in
    Http.expectStringResponse toMsg <|
        resolve
            (Decode.decodeCustom { fieldSeparator = ';' } FieldNamesFromFirstRow decoder_
                >> Result.mapError Decode.errorToString
            )



-- SUBSCRIPTIONS


subscriptions : UrlPath -> Model -> Sub Msg
subscriptions _ _ =
    Sub.none



-- DATA


data : BackendTask FatalError Data
data =
    BackendTask.succeed ()



-- VIEW


view :
    Data
    ->
        { path : UrlPath
        , route : Maybe Route
        }
    -> Model
    -> (Msg -> msg)
    -> View msg
    -> { body : List (Html.Html msg), title : String }
view sharedData page model toMsg pageView =
    { title = pageView.title
    , body =
        List.map Html.Styled.toUnstyled
            [ global
                [ Css.Global.body
                    [ backgroundColor (hsl 0 0 0.4)
                    , color (hsla 0 0 1 0.9)
                    ]
                ]
            , main_ [] pageView.body
            ]
    }
