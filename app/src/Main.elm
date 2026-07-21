module Main exposing (main)

{-| Application entry point. A hand-written `Browser.application` that wires
together the shared model, the client-side router, and each page — replacing the
elm-pages framework.
-}

import Browser
import Browser.Navigation as Nav
import Css exposing (height, vh)
import Css.Global
import Effect exposing (Effect)
import Html.Styled
import Json.Decode as Decode
import Page.Debug
import Page.Index
import Page.Wec.Event
import Route exposing (Route)
import Shared
import Shared.Msg
import Url exposing (Url)
import View exposing (View)


main : Program Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = ClickedLink
        , onUrlChange = ChangedUrl
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url
    , shared : Shared.Model
    , page : Page
    }


type Page
    = IndexPage
    | DebugPage Page.Debug.Model
    | WecEventPage Page.Wec.Event.Model
    | NotFoundPage


init : Decode.Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        ( shared, sharedEffect ) =
            Shared.init flags

        ( page, pageCmd ) =
            initPage (Route.fromUrl url)
    in
    ( { key = key, url = url, shared = shared, page = page }
    , Cmd.batch
        [ sharedEffect
            |> Effect.toCmd { fromPageMsg = SharedMsg, fromSharedMsg = SharedMsg }
        , pageCmd
        ]
    )


initPage : Maybe Route -> ( Page, Cmd Msg )
initPage maybeRoute =
    case maybeRoute of
        Nothing ->
            ( NotFoundPage, Cmd.none )

        Just Route.Index ->
            ( IndexPage, Cmd.none )

        Just Route.Debug ->
            Page.Debug.init
                |> Tuple.mapBoth DebugPage (toPageCmd DebugMsg)

        Just (Route.WecEvent params) ->
            Page.Wec.Event.init params
                |> Tuple.mapBoth WecEventPage (toPageCmd WecEventMsg)


toPageCmd : (pageMsg -> Msg) -> Effect pageMsg -> Cmd Msg
toPageCmd fromPageMsg effect =
    Effect.toCmd
        { fromPageMsg = fromPageMsg, fromSharedMsg = SharedMsg }
        effect



-- UPDATE


type Msg
    = ClickedLink Browser.UrlRequest
    | ChangedUrl Url
    | SharedMsg Shared.Msg.Msg
    | DebugMsg Page.Debug.Msg
    | WecEventMsg Page.Wec.Event.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( ClickedLink urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        ( ChangedUrl url, _ ) ->
            let
                ( page, pageCmd ) =
                    initPage (Route.fromUrl url)
            in
            ( { model | url = url, page = page }, pageCmd )

        ( SharedMsg sharedMsg, _ ) ->
            let
                ( shared, effect ) =
                    Shared.update sharedMsg model.shared
            in
            ( { model | shared = shared }
            , effect
                |> Effect.toCmd { fromPageMsg = SharedMsg, fromSharedMsg = SharedMsg }
            )

        ( DebugMsg pageMsg, DebugPage pageModel ) ->
            Page.Debug.update pageMsg pageModel
                |> updatePage model DebugPage DebugMsg

        ( WecEventMsg pageMsg, WecEventPage pageModel ) ->
            Page.Wec.Event.update pageMsg pageModel
                |> updatePage model WecEventPage WecEventMsg

        _ ->
            -- Message for a page that is no longer active; ignore it.
            ( model, Cmd.none )


updatePage : Model -> (pageModel -> Page) -> (pageMsg -> Msg) -> ( pageModel, Effect pageMsg ) -> ( Model, Cmd Msg )
updatePage model toPage fromPageMsg ( pageModel, effect ) =
    ( { model | page = toPage pageModel }
    , toPageCmd fromPageMsg effect
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Shared.subscriptions model.shared |> Sub.map SharedMsg
        , case model.page of
            WecEventPage pageModel ->
                Page.Wec.Event.subscriptions model.shared pageModel
                    |> Sub.map WecEventMsg

            _ ->
                Sub.none
        ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        { title, body } =
            viewPage model
    in
    { title = title
    , body =
        List.map Html.Styled.toUnstyled (globalReset :: body)
    }


globalReset : Html.Styled.Html msg
globalReset =
    Css.Global.global
        [ Css.Global.html [ height (vh 100) ]
        , Css.Global.body [ height (vh 100) ]
        ]


viewPage : Model -> View Msg
viewPage model =
    case model.page of
        IndexPage ->
            Page.Index.view

        DebugPage pageModel ->
            Page.Debug.view model.shared pageModel
                |> View.map DebugMsg

        WecEventPage pageModel ->
            Page.Wec.Event.view model.shared pageModel
                |> View.map WecEventMsg

        NotFoundPage ->
            { title = "Not Found"
            , body = [ Html.Styled.text "Page not found. Maybe try another URL?" ]
            }
