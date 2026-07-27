module Route exposing (Route(..), fromUrl, toString, href)

{-| Hand-written client-side routing, replacing elm-pages' generated `Route`
module.

@docs Route, fromUrl, toString, href

-}

import Html.Styled
import Html.Styled.Attributes
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, s, string, top)


{-| -}
type Route
    = Index
    | Debug
    | WecEvent { season : String, event : String }


parser : Parser (Route -> a) a
parser =
    Parser.oneOf
        [ Parser.map Index top
        , Parser.map Debug (s "debug")
        , Parser.map (\season event -> WecEvent { season = season, event = event })
            (s "wec" </> string </> string)
        ]


{-| Parse a `Url` into a `Route`. Returns `Nothing` for unknown paths.
-}
fromUrl : Url -> Maybe Route
fromUrl =
    Parser.parse parser


{-| Render a `Route` as an absolute path.
-}
toString : Route -> String
toString route =
    case route of
        Index ->
            "/"

        Debug ->
            "/debug"

        WecEvent { season, event } ->
            "/wec/" ++ season ++ "/" ++ event


{-| A convenient `href` attribute for internal links.
-}
href : Route -> Html.Styled.Attribute msg
href route =
    Html.Styled.Attributes.href (toString route)
