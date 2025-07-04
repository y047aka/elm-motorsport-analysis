port module Main exposing (main)

import Args exposing (Args)
import Data.FormulaE
import Data_Cli.FormulaE as FormulaE
import Data_Cli.FormulaE.Preprocess as Preprocess_FormulaE
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
            case args.mode of
                "wec" ->
                    Wec.getLaps args.eventId (CsvLoaded_Wec args.eventId)

                "fe" ->
                    FormulaE.getLaps args.eventId (CsvLoaded_FormulaE args.eventId)

                _ ->
                    selectMode

        Nothing ->
            selectMode
    )


selectMode : Cmd Msg
selectMode =
    [ { title = "WEC", value = "wec", description = "World Endurance Championship" }
    , { title = "Formula E", value = "fe", description = "Formula E Championship" }
    ]
        |> Select.option "Select Mode : "
        |> output


selectEvent : String -> Cmd Msg
selectEvent mode =
    case mode of
        "wec" ->
            [ "qatar_1812km", "imola_6h", "spa_6h", "le_mans_24h", "fuji_6h", "bahrain_8h" ]
                |> List.map toItem
                |> Select.option "Select Event ID : "
                |> output

        "fe" ->
            [ "R08_tokyo" ]
                |> List.map toItem
                |> Select.option "Select Event ID : "
                |> output

        _ ->
            selectMode


toItem : String -> Prompts.Item
toItem eventId =
    { title = eventId
    , value = eventId
    , description = ""
    }



-- UPDATE


type Msg
    = InputMode String
    | InputEventId String String
    | CsvLoaded_Wec String (Result Http.Error (List Wec.Lap))
    | CsvLoaded_LeMans24h String (Result Http.Error (List LeMans24h.Lap))
    | CsvLoaded_FormulaE String (Result Http.Error (List FormulaE.Lap))
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InputMode mode ->
            ( { model | args = Just { eventId = "", mode = mode } }
            , selectEvent mode
            )

        InputEventId mode eventId ->
            ( { model | args = Just { eventId = eventId, mode = mode } }
            , case mode of
                "wec" ->
                    Wec.getLaps eventId (CsvLoaded_Wec eventId)

                "fe" ->
                    FormulaE.getLaps eventId (CsvLoaded_FormulaE eventId)

                _ ->
                    Cmd.none
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

        CsvLoaded_FormulaE fileName (Ok decoded) ->
            ( model
            , exitWithMsg
                ( 0
                , Maybe.withDefault "" <| Maybe.map .eventId model.args
                , formulaEEventEncoder
                    { name = fileName
                    , laps = decoded
                    , preprocessed = Preprocess_FormulaE.preprocess { laps = decoded }
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


formulaEEventEncoder : Data.FormulaE.Event -> JE.Value
formulaEEventEncoder { name, laps, preprocessed } =
    let
        toEventName eventId =
            case eventId of
                "R08_tokyo" ->
                    "Tokyo E-Prix"

                _ ->
                    "Encoding Error"
    in
    JE.object
        [ ( "name", JE.string (toEventName name) )
        , ( "laps", JE.list FormulaE.lapEncoder laps )
        , ( "preprocessed", JE.list FormulaE.carEncoder preprocessed )
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        decoder =
            JD.oneOf
                [ JD.map InputMode
                    (JD.string
                        |> JD.andThen
                            (\mode ->
                                if mode == "wec" || mode == "fe" then
                                    JD.succeed mode

                                else
                                    JD.fail "not a valid mode"
                            )
                    )
                , JD.map2 InputEventId
                    (JD.field "mode" JD.string)
                    (JD.field "eventId" JD.string)
                ]
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
