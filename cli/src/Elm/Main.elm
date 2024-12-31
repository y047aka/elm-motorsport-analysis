port module Main exposing (main)

import Args exposing (Args)
import Http
import Json.Decode as JD
import Json.Encode as JE
import Motorsport.Class as Class
import Motorsport.Duration as Duration
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
            ( model
            , Wec.getLaps eventId CsvLoaded
            )

        CsvLoaded (Ok decoded) ->
            ( model
            , ( exitWithMsg ( 0, JE.list lapEncoder decoded ))
            )

        _ ->
            ( model
            , exitWithMsg ( 1, JE.string "Error" )
            )


lapEncoder : Wec.Lap -> JE.Value
lapEncoder lap =
    JE.object
        [ ( "carNumber", JE.string lap.carNumber )
        , ( "driverNumber", JE.int lap.driverNumber )
        , ( "lapNumber", JE.int lap.lapNumber )
        , ( "lapTime", JE.string (Duration.toString lap.lapTime) )
        , ( "lapImprovement", JE.int lap.lapImprovement )
        , ( "crossingFinishLineInPit", JE.string lap.crossingFinishLineInPit )
        , ( "s1", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString lap.s1) )
        , ( "s1Improvement", JE.int lap.s1Improvement )
        , ( "s2", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString lap.s2) )
        , ( "s2Improvement", JE.int lap.s2Improvement )
        , ( "s3", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString lap.s3) )
        , ( "s3Improvement", JE.int lap.s3Improvement )
        , ( "kph", JE.float lap.kph )
        , ( "elapsed", JE.string (Duration.toString lap.elapsed) )
        , ( "hour", JE.string (Duration.toString lap.hour) )
        , ( "topSpeed", JE.string (Maybe.withDefault "" <| Maybe.map String.fromFloat lap.topSpeed) )
        , ( "driverName", JE.string lap.driverName )
        , ( "pitTime", JE.string (Maybe.withDefault "" <| Maybe.map Duration.toString lap.pitTime) )
        , ( "class", JE.string <| Class.toString lap.class )
        , ( "group", JE.string lap.group )
        , ( "team", JE.string lap.team )
        , ( "manufacturer", JE.string lap.manufacturer )
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


port exitWithMsg : ( Int, JE.Value ) -> Cmd msg


port input : (JD.Value -> msg) -> Sub msg
