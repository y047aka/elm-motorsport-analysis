module UI.Notice exposing (view, httpError)

{-| What a page shows in place of what it cannot show. Left empty, the round
that never arrives and the round still on its way look the same.

@docs view, httpError

-}

import Html exposing (Html, div, p, text)
import Html.Attributes exposing (class)
import Http


{-| -}
view : { headline : String, detail : String } -> Html msg
view notice =
    div [ class "mx-auto max-w-md px-6 py-20 text-center" ]
        [ p [ class "text-sm font-medium" ] [ text notice.headline ]
        , p [ class "mt-2 text-sm opacity-60" ] [ text notice.detail ]
        ]


{-| The failure in the words of the thing that failed. `BadBody` is handed on
unedited: the decoder's own report is long and worth reading.
-}
httpError : Http.Error -> String
httpError error =
    case error of
        Http.BadUrl url ->
            "Not a URL this app can ask for: " ++ url

        Http.Timeout ->
            "The request timed out."

        Http.NetworkError ->
            "No answer from the server."

        Http.BadStatus status ->
            "The server answered with " ++ String.fromInt status ++ "."

        Http.BadBody reason ->
            reason
