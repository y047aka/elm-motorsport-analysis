port module Main exposing (main)

import Args exposing (Args)
import Http
import Json.Decode as JD
import Json.Encode as JE
import Prompts.Text as Text
import Wec


main : Program Flag Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


type alias Flag =
    String



-- MODEL


type alias Model =
    { args : Maybe Args }


init : Flag -> ( Model, Cmd Msg )
init flags =
    let
        maybeArgs =
            Args.fromString flags
    in
    ( { args = maybeArgs}
    , case maybeArgs of
        Just args ->
            Wec.getLaps args.eventId CsvLoaded

        Nothing ->
            output <| Text.option "Imput Event ID : "
    )



-- UPDATE


type Msg
    = InputEventId String
    | CsvLoaded (Result Http.Error (List Wec.Lap))
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InputEventId eventId ->
            ( { model | args = Just { eventId = eventId, repoName = Maybe.withDefault "" <| Maybe.map .repoName model.args } }
            , Wec.getLaps eventId CsvLoaded
            )

        CsvLoaded (Ok decoded) ->
            ( model
            , ( exitWithMsg
                ( 0
                , Maybe.withDefault "" <| Maybe.map .eventId model.args
                , JE.list Wec.lapEncoder decoded
                )
              )
            )

        _ ->
            ( model
            , exitWithMsg ( 1, "Error", JE.null )
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        decoder =
            JD.map InputEventId JD.string
    in
    [ JD.decodeValue decoder
        >> Result.withDefault NoOp
        |> input
    ]
        |> Sub.batch



-- PORTS


port output : JE.Value -> Cmd msg


port exitWithMsg : ( Int, String, JE.Value ) -> Cmd msg


port input : (JD.Value -> msg) -> Sub msg
