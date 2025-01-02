port module Main exposing (main)

import Args exposing (Args)
import Data.Wec.Event as WecEvent
import Http
import Json.Decode as JD
import Json.Encode as JE
import Prompts
import Prompts.Select as Select
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
    ( { args = maybeArgs }
    , case maybeArgs of
        Just args ->
            Wec.getLaps args.eventId (CsvLoaded args.eventId)

        Nothing ->
            [ "le_mans_24h", "fuji_6h", "bahrain_8h" ]
                |> List.map toItem
                |> Select.option "Select Event ID : "
                |> output
    )


toItem : String -> Prompts.Item
toItem eventId =
    { title = eventId
    , value = eventId
    , description = ""
    }



-- UPDATE


type Msg
    = InputEventId String
    | CsvLoaded String (Result Http.Error (List Wec.Lap))
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InputEventId eventId ->
            ( { model | args = Just { eventId = eventId, repoName = Maybe.withDefault "" <| Maybe.map .repoName model.args } }
            , Wec.getLaps eventId (CsvLoaded eventId)
            )

        CsvLoaded fileName (Ok decoded) ->
            ( model
            , exitWithMsg
                ( 0
                , Maybe.withDefault "" <| Maybe.map .eventId model.args
                , eventEncoder
                    { name = fileName
                    , laps = decoded
                    }
                )
            )

        _ ->
            ( model
            , exitWithMsg ( 1, "Error", JE.null )
            )


eventEncoder : WecEvent.Event -> JE.Value
eventEncoder { name, laps } =
    let
        toEventName eventId =
            case eventId of
                "le_mans_24h" ->
                    "24 Hours of Le Mans"

                "fuji_6h" ->
                    "6 Hours of Fuji"

                "bahrain_8h" ->
                    "8 Hours of Bahrain"

                _ ->
                    "Encoding Error"
    in
    JE.object
        [ ( "name", JE.string (toEventName name) )
        , ( "laps", JE.list Wec.lapEncoder laps )
        ]



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
