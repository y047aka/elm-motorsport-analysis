module View exposing
    ( View, map
    , none, fromString
    , toBrowserDocument
    )

{-|

@docs View, map
@docs none, fromString
@docs toBrowserDocument

-}

import Browser
import Css exposing (..)
import Css.Global exposing (global)
import Html.Styled exposing (main_)
import Route exposing (Route)
import Shared.Model


type alias View msg =
    { title : String
    , body : List (Html.Styled.Html msg)
    }


{-| Used internally by Elm Land to create your application
so it works with Elm's expected `Browser.Document msg` type.
-}
toBrowserDocument :
    { shared : Shared.Model.Model
    , route : Route ()
    , view : View msg
    }
    -> Browser.Document msg
toBrowserDocument { view } =
    { title = view.title
    , body =
        List.map Html.Styled.toUnstyled
            [ global
                [ Css.Global.body
                    [ backgroundColor (hsl 0 0 0.4)
                    , color (hsla 0 0 1 0.9)
                    ]
                ]
            , main_ [] view.body
            ]
    }


{-| Used internally by Elm Land to connect your pages together.
-}
map : (msg1 -> msg2) -> View msg1 -> View msg2
map fn view =
    { title = view.title
    , body = List.map (Html.Styled.map fn) view.body
    }


{-| Used internally by Elm Land whenever transitioning between
authenticated pages.
-}
none : View msg
none =
    { title = ""
    , body = []
    }


{-| If you customize the `View` module, anytime you run `elm-land add page`,
the generated page will use this when adding your `view` function.

That way your app will compile after adding new pages, and you can see
the new page working in the web browser!

-}
fromString : String -> View msg
fromString moduleName =
    { title = moduleName
    , body = [ Html.Styled.text moduleName ]
    }
