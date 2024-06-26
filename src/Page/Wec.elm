module Page.Wec exposing (Model, Msg, init, update, view)

import Chart.Chart as Chart
import Data.Wec.Car as Wec
import Data.Wec.Decoder as Wec
import Effect exposing (Effect)
import Html.Styled as Html exposing (Html)
import List.Extra as List
import Motorsport.Car as Motorsport
import Shared



-- MODEL


type alias Model =
    {}


init : ( Model, Effect Msg )
init =
    ( {}
    , Effect.fetchCsv "/static/23_Analysis_Race_Hour 24.csv"
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )



-- VIEW


view : Shared.Model -> Model -> List (Html msg)
view { raceControl, ordersByLap } _ =
    [ Chart.view
        { cars = List.map (summarize ordersByLap) raceControl.cars
        , ordersByLap = ordersByLap
        }
    ]


type alias OrdersByLap =
    List { lapNumber : Int, order : List String }


summarize : OrdersByLap -> Motorsport.Car -> Wec.Car
summarize ordersByLap { carNumber, class, group, team, manufacturer, laps } =
    { carNumber = carNumber
    , class = class
    , group = group
    , team = team
    , manufacturer = manufacturer
    , startPosition = Maybe.withDefault 0 <| getPositionAt { carNumber = carNumber, lapNumber = 1 } ordersByLap
    , positions =
        List.indexedMap
            (\index _ -> Maybe.withDefault 0 <| getPositionAt { carNumber = carNumber, lapNumber = index + 1 } ordersByLap)
            laps
    , laps = laps
    }


getPositionAt : { carNumber : String, lapNumber : Int } -> OrdersByLap -> Maybe Int
getPositionAt { carNumber, lapNumber } ordersByLap =
    ordersByLap
        |> List.find (.lapNumber >> (==) lapNumber)
        |> Maybe.andThen (.order >> List.findIndex ((==) carNumber))
