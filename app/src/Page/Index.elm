module Page.Index exposing (view)

{-| The top page. It holds no state of its own, so it exposes only a `view`; the
calendar it lists is loaded once by `Shared`.

@docs view

-}

import Data.Wec.Calendar exposing (Round, Season)
import Html exposing (Html, a, div, h1, h2, h3, header, main_, p, section, span, text)
import Html.Attributes exposing (class)
import Route
import Shared
import UI.Shadcn.Badge as Badge
import UI.Shadcn.Card as Card
import View exposing (View)


{-| The seasons come out in the order the file lists them, first one latest.
Sorting them here would be this page holding an opinion the file already
carries.
-}
view : Shared.Model -> View msg
view { calendar } =
    { title = "Race Analysis"
    , body =
        [ div
            [ class "dark h-full overflow-y-auto bg-background text-foreground"
            ]
            [ pageHeader
            , main_ [ class "mx-auto flex max-w-5xl flex-col gap-12 px-6 pb-20" ]
                (List.indexedMap (\i season -> seasonSection { isLatest = i == 0 } season) calendar)
            ]
        ]
    }


pageHeader : Html msg
pageHeader =
    header [ class "mx-auto max-w-5xl px-6 pt-14 pb-10" ]
        [ Badge.view { label = "FIA WEC", variant = Badge.OutlinePrimary } []
        , h1 [ class "mt-3 text-4xl font-bold tracking-tight" ] [ text "Race Analysis" ]
        , p [ class "mt-2 text-sm opacity-60" ]
            [ text "Select a race to explore lap times, gaps and position changes." ]
        ]


seasonSection : { isLatest : Bool } -> Season -> Html msg
seasonSection { isLatest } { season, rounds } =
    let
        seasonLabel =
            String.fromInt season
    in
    section []
        [ div [ class "mb-4 flex items-center gap-3" ]
            [ h2 [ class "text-xl font-semibold tracking-tight" ] [ text ("WEC " ++ seasonLabel) ]
            , if isLatest then
                Badge.view { label = "Latest", variant = Badge.Primary } []

              else
                text ""
            , span [ class "ml-auto text-xs tabular-nums opacity-50" ]
                [ text (String.fromInt (List.length rounds) ++ " races") ]
            ]
        , div [ class "grid gap-4 sm:grid-cols-2 lg:grid-cols-3" ]
            (List.map (eventCard seasonLabel) rounds)
        ]


eventCard : String -> Round -> Html msg
eventCard season round =
    a
        [ Route.href (Route.WecEvent { season = season, event = round.id })
        , class "group block transition duration-150 hover:-translate-y-0.5 hover:brightness-125"
        ]
        [ Card.card []
            [ Card.header []
                [ Card.description [] [ text (formatDate round.date) ]
                , Card.title [] [ text round.name ]
                , Card.action []
                    [ span [ class "text-lg opacity-20 transition-opacity group-hover:opacity-70" ]
                        [ text "→" ]
                    ]
                ]
            ]
        ]


{-| Formats an ISO date (`2026-04-19`) for display (`Apr 19, 2026`).
-}
formatDate : String -> String
formatDate isoDate =
    case String.split "-" isoDate of
        [ year, month, day ] ->
            monthAbbr month ++ " " ++ trimLeadingZero day ++ ", " ++ year

        _ ->
            isoDate


monthAbbr : String -> String
monthAbbr month =
    case month of
        "01" ->
            "Jan"

        "02" ->
            "Feb"

        "03" ->
            "Mar"

        "04" ->
            "Apr"

        "05" ->
            "May"

        "06" ->
            "Jun"

        "07" ->
            "Jul"

        "08" ->
            "Aug"

        "09" ->
            "Sep"

        "10" ->
            "Oct"

        "11" ->
            "Nov"

        "12" ->
            "Dec"

        _ ->
            month


trimLeadingZero : String -> String
trimLeadingZero day =
    String.toInt day
        |> Maybe.map String.fromInt
        |> Maybe.withDefault day
