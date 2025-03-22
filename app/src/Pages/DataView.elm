module Pages.DataView exposing (Model, Msg, page)

import DataView exposing (Config, intColumn, stringColumn)
import DataView.Options exposing (FilteringOption(..), Options, PaginationOption(..), SelectingOption(..), SortingOption(..))
import DemoCss exposing (tableDefaultCss)
import Effect exposing (Effect)
import Html.Styled exposing (div)
import Html.Styled.Attributes exposing (class)
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
    { data : List Person
    , tableState : DataView.Model
    }


type alias Person =
    { name : String
    , age : Int
    , cats : Int
    }


init : () -> ( Model, Effect Msg )
init () =
    ( { data = data
      , tableState = DataView.init "demo" options
      }
    , Effect.none
    )


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
    { sorting = Sorting
    , filtering = Filtering
    , selecting = Selecting
    , pagination = Pagination 10
    }



-- UPDATE


type Msg
    = NoOp
    | TableMsg DataView.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )

        TableMsg tableMsg ->
            ( { model | tableState = DataView.update tableMsg model.tableState }, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view _ model =
    { title = "DataView"
    , body =
        [ div []
            [ tableDefaultCss
            , div [ class "container" ] [ DataView.view config model.tableState model.data ]
            ]
        ]
    }


config : Config Person Msg
config =
    { toId = .name
    , toMsg = TableMsg
    , columns =
        [ stringColumn
            { label = "Name"
            , toString = .name
            }
        , intColumn
            { label = "Age"
            , toInt = .age
            }
        , intColumn
            { label = "Cats"
            , toInt = .cats
            }
        ]
    }
