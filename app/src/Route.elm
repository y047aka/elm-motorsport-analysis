module Route exposing (Route(..), fromUrl, toString, href)

{-| Client-side routing.

@docs Route, fromUrl, toString, href

-}

import Html
import Html.Attributes
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, s, string, top)


type Route
    = Index
    | WecEvent { season : String, event : String }


parser : Parser (Route -> a) a
parser =
    Parser.oneOf
        [ Parser.map Index top
        , Parser.map (\season event -> WecEvent { season = season, event = event })
            (s "wec" </> string </> string)
        ]


fromUrl : Url -> Maybe Route
fromUrl =
    Parser.parse parser


toString : Route -> String
toString route =
    case route of
        Index ->
            "/"

        WecEvent { season, event } ->
            "/wec/" ++ season ++ "/" ++ event


href : Route -> Html.Attribute msg
href route =
    Html.Attributes.href (toString route)
