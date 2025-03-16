module Pages.DataView exposing (Model, Msg, page)

import DataView
import DataView.Options exposing (DraggingOption(..), EditingOption(..), FillOption(..), FilteringOption(..), Options(..), PaginationOption(..), SelectingOption(..), SortingOption(..))
import DemoCss exposing (pageCss, tableDefaultCss, tableOldDefaultCss)
import Effect exposing (Effect)
import Html.Styled exposing (div, input)
import Html.Styled.Attributes exposing (class, type_, value)
import Html.Styled.Events exposing (onInput)
import Page exposing (Page)
import Route exposing (Route)
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , view = view shared
        , subscriptions = \_ -> Sub.none
        }



-- MODEL


type alias Model =
    { tableState : DataView.Model Msg Person }


type alias Person =
    { name : String
    , age : Int
    , cats : Int
    }


init : () -> ( Model, Effect Msg )
init () =
    ( { tableState = DataView.init "demo" columns data options }, Effect.none )


columns : List (DataView.Column Msg Person)
columns =
    [ DataView.Column
        "Name"
        "name"
        .name
        (\p i -> input [ type_ "text", value p.name, onInput <| Edit "name" i ] [])
        .name
        (String.startsWith << .name)
        (\r v -> { r | name = v })
    , DataView.Column
        "Age"
        "age"
        (String.fromInt << .age)
        (\p i -> input [ type_ "text", value <| String.fromInt p.age, onInput <| Edit "age" i ] [])
        (String.fromInt << .age)
        (String.startsWith << String.fromInt << .age)
        (\r v ->
            case String.toInt v of
                Just age ->
                    { r | age = age }

                Nothing ->
                    r
        )
    , DataView.Column
        "Cats"
        "cats"
        (String.fromInt << .cats)
        (\p i -> input [ type_ "text", value <| String.fromInt p.cats, onInput <| Edit "cats" i ] [])
        (String.fromInt << .cats)
        (String.startsWith << String.fromInt << .cats)
        (\r v ->
            case String.toInt v of
                Just cats ->
                    { r | cats = cats }

                Nothing ->
                    r
        )
    ]


data : List Person
data =
    [ Person "Bob" 30 2
    , Person "Jack" 30 1
    , Person "Jane" 31 2
    , Person "William" 31 3
    , Person "Jolene" 32 3
    , Person "Billy" 43 5
    , Person "Holly" 32 1
    , Person "Xavier" 33 1
    , Person "Jimmy" 35 0
    , Person "John" 34 0
    , Person "Ashley" 34 1
    , Person "Michael" 33 2
    , Person "Eva" 41 3
    , Person "Claire" 44 4
    , Person "Lindsay" 42 2
    , Person "Natalie" 40 4
    ]


options : Options
options =
    Options Sorting Filtering Selecting Dragging Editing (Pagination 10) (Fill 10)



-- UPDATE


type Msg
    = NoOp
    | Edit String Int String
    | TableMsg DataView.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )

        TableMsg tableMsg ->
            ( { model | tableState = DataView.update tableMsg model.tableState }, Effect.none )

        Edit key index value ->
            ( { model | tableState = DataView.update (DataView.Edit key index value) model.tableState }, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view _ model =
    { title = "DataView"
    , body =
        [ div []
            [ pageCss
            , tableOldDefaultCss
            , div [ class "container" ] [ DataView.view model.tableState TableMsg ]
            ]
        ]
    }
