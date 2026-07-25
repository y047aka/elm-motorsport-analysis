module Page.Index exposing (view)

{-| The top page. It is stateless, so it exposes only a `view`.

@docs view

-}

import Data.Series.EventSummary exposing (EventSummary)
import Data.Series.Wec_2024 exposing (wec_2024)
import Data.Series.Wec_2025 exposing (wec_2025)
import Data.Series.Wec_2026 exposing (wec_2026)
import Html.Styled exposing (Html, a, div, h1, h2, h3, header, main_, p, section, span, text)
import Html.Styled.Attributes exposing (attribute, class)
import Route
import View exposing (View)


view : View msg
view =
    { title = "Race Analysis"
    , body =
        [ div
            [ attribute "data-theme" "forest"
            , class "h-full overflow-y-auto bg-base-100 text-base-content"
            ]
            [ pageHeader
            , main_ [ class "mx-auto flex max-w-5xl flex-col gap-12 px-6 pb-20" ]
                [ seasonSection { season = "2026", isLatest = True } wec_2026
                , seasonSection { season = "2025", isLatest = False } wec_2025
                , seasonSection { season = "2024", isLatest = False } wec_2024
                ]
            ]
        ]
    }


pageHeader : Html msg
pageHeader =
    header [ class "mx-auto max-w-5xl px-6 pt-14 pb-10" ]
        [ span [ class "badge badge-sm badge-outline badge-primary" ] [ text "FIA WEC" ]
        , h1 [ class "mt-3 text-4xl font-bold tracking-tight" ] [ text "Race Analysis" ]
        , p [ class "mt-2 text-sm opacity-60" ]
            [ text "Select a race to explore lap times, gaps and position changes." ]
        ]


seasonSection : { season : String, isLatest : Bool } -> List EventSummary -> Html msg
seasonSection { season, isLatest } events =
    section []
        [ div [ class "mb-4 flex items-center gap-3" ]
            [ h2 [ class "text-xl font-semibold tracking-tight" ] [ text ("WEC " ++ season) ]
            , if isLatest then
                span [ class "badge badge-sm badge-primary" ] [ text "Latest" ]

              else
                text ""
            , span [ class "ml-auto text-xs tabular-nums opacity-50" ]
                [ text (String.fromInt (List.length events) ++ " races") ]
            ]
        , div [ class "grid gap-4 sm:grid-cols-2 lg:grid-cols-3" ]
            (List.map (eventCard season) events)
        ]


eventCard : String -> EventSummary -> Html msg
eventCard season eventSummary =
    a
        [ Route.href (Route.WecEvent { season = season, event = eventSummary.id })
        , class "group card card-border border-base-300 bg-base-200 transition duration-150 hover:-translate-y-0.5 hover:border-primary/50 hover:brightness-125"
        ]
        [ div [ class "card-body gap-3 p-5" ]
            [ span [ class "text-xs tabular-nums opacity-60" ]
                [ text (formatDate eventSummary.date) ]
            , div [ class "flex items-end justify-between gap-2" ]
                [ h3 [ class "card-title text-base leading-snug" ] [ text eventSummary.name ]
                , span [ class "text-lg opacity-20 transition-opacity group-hover:opacity-70" ]
                    [ text "→" ]
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
