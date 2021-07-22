module Main exposing (main)

import Browser exposing (Document)
import Browser.Navigation as Nav exposing (Key)
import Html.Styled exposing (text, toUnstyled)
import Url exposing (Url)



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
    {}


init : () -> Url -> Key -> ( Model, Cmd Msg )
init _ url key =
    ( {}, Cmd.none )



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        _ ->
            ( {}, Cmd.none )



-- VIEW


view : Model -> Document Msg
view model =
    { title = "Race Analysis"
    , body = [ toUnstyled <| text "Initial" ]
    }
