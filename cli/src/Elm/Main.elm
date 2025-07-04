port module Main exposing (main)

import Args exposing (Args)
import Data_Cli.LeMans24h as LeMans24h
import Data_Cli.LeMans24h.Preprocess as Preprocess_LeMans24h
import Data_Cli.Wec as Wec
import Data_Cli.Wec.Preprocess as Preprocess_Wec
import Http
import Json.Decode as JD
import Json.Encode as JE
import Motorsport.Car exposing (Car)
import Prompts
import Prompts.Select as Select


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
            Wec.getLaps args.eventId (CsvLoaded_Wec args.eventId)

        Nothing ->
            [ "qatar_1812km", "imola_6h", "spa_6h", "le_mans_24h", "fuji_6h", "bahrain_8h" ]
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
    | CsvLoaded_Wec String (Result Http.Error (List Wec.Lap))
    | CsvLoaded_LeMans24h String (Result Http.Error (List LeMans24h.Lap))
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InputEventId eventId ->
            ( { model | args = Just { eventId = eventId, repoName = Maybe.withDefault "" <| Maybe.map .repoName model.args } }
            , case eventId of
                "le_mans_24h" ->
                    LeMans24h.getLaps eventId (CsvLoaded_LeMans24h eventId)

                _ ->
                    Wec.getLaps eventId (CsvLoaded_Wec eventId)
            )

        CsvLoaded_Wec fileName (Ok decoded) ->
            ( model
            , exitWithMsg
                ( 0
                , Maybe.withDefault "" <| Maybe.map .eventId model.args
                , eventEncoder
                    { name = fileName
                    , laps = decoded
                    , preprocessed = Preprocess_Wec.preprocess { laps = decoded }
                    }
                )
            )

        CsvLoaded_LeMans24h fileName (Ok decoded) ->
            ( model
            , exitWithMsg
                ( 0
                , Maybe.withDefault "" <| Maybe.map .eventId model.args
                , eventEncoder_LeMans24h
                    { name = fileName
                    , laps = decoded
                    , preprocessed = Preprocess_LeMans24h.preprocess { laps = decoded }
                    }
                )
            )

        _ ->
            ( model
            , exitWithMsg ( 1, "Error", JE.null )
            )


eventEncoder :
    { name : String
    , laps : List Wec.Lap
    , preprocessed : List Car
    }
    -> JE.Value
eventEncoder { name, laps, preprocessed } =
    let
        toEventName eventId =
            case eventId of
                "qatar_1812km" ->
                    "Qatar 1812km"

                "imola_6h" ->
                    "6 Hours of Imola"

                "spa_6h" ->
                    "6 Hours of Spa"

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
        , ( "preprocessed", JE.list Wec.carEncoder preprocessed )
        ]


eventEncoder_LeMans24h :
    { name : String
    , laps : List LeMans24h.Lap
    , preprocessed : List Car
    }
    -> JE.Value
eventEncoder_LeMans24h { name, laps, preprocessed } =
    let
        toEventName eventId =
            case eventId of
                "le_mans_24h" ->
                    "24 Hours of Le Mans"

                _ ->
                    "Encoding Error"
    in
    JE.object
        [ ( "name", JE.string (toEventName name) )
        , ( "laps", JE.list LeMans24h.lapEncoder laps )
        , ( "preprocessed", JE.list LeMans24h.carEncoder preprocessed )
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
