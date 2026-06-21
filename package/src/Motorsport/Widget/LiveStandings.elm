module Motorsport.Widget.LiveStandings exposing (Props, view)

import Css exposing (after, backgroundColor, before, hover, property, qt)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled exposing (Html, button, div, li, text)
import Html.Styled.Attributes exposing (attribute, class, css)
import Html.Styled.Events exposing (onClick)
import Html.Styled.Keyed as Keyed
import Html.Styled.Lazy as Lazy
import Motorsport.Car as Car
import Motorsport.Class as Class
import Motorsport.Gap as Gap
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Motorsport.Widget.CarStatus as CarStatus


type alias Props msg =
    { eventSummary : EventSummary
    , standings : Standings
    , onSelectCar : StandingsEntry -> msg
    , popoverTarget : String
    }


view : Props msg -> Html msg
view props =
    div
        [ css
            [ property "height" "100%"
            , property "display" "grid"
            , property "grid-template-rows" "repeat(3, 1fr)"
            , property "row-gap" "10px"
            ]
        ]
        (List.map
            (\( class_, cars ) ->
                div
                    [ class "card bg-base-200 overflow-hidden"
                    , css
                        [ property "display" "grid"
                        , property "grid-template-rows" "auto 1fr"
                        ]
                    ]
                    [ div
                        [ css
                            [ property "display" "flex"
                            , property "align-items" "center"
                            , property "column-gap" "0.5em"
                            , property "padding" "8px 10px"
                            , property "font-size" "10px"
                            , property "font-weight" "bold"
                            , before
                                [ property "display" "block"
                                , property "content" (qt "")
                                , property "width" "0.2em"
                                , property "height" "1.2em"
                                , property "border-radius" "2px"
                                , backgroundColor (Class.toHexColor props.eventSummary.season class_)
                                ]
                            ]
                        ]
                        [ text (Class.toString class_) ]
                    , Keyed.node "ul"
                        [ class "list"
                        , css
                            [ property "overflow-y" "scroll"
                            , property "padding" "0 10px 10px"
                            ]
                        ]
                        (cars
                            |> List.map
                                (\item ->
                                    ( item.metadata.carNumber
                                    , Lazy.lazy3 carRow props.popoverTarget props.onSelectCar item
                                    )
                                )
                        )
                    ]
            )
            (Standings.toClassList props.standings)
        )


formatDriverName : String -> String
formatDriverName fullName =
    case String.words fullName of
        _ :: rest ->
            -- 姓全体を大文字で表示
            rest |> List.map String.toUpper |> String.join " "

        [] ->
            fullName


{-| 行全体を popovertarget 付きの button にすることで, クリック時にブラウザが
詳細ポップオーバーを開く. 同時に onSelect で対象車を Model へ記録する.
-}
carRow : String -> (StandingsEntry -> msg) -> StandingsEntry -> Html msg
carRow popoverTarget onSelect item =
    li []
        [ button
            [ onClick (onSelect item)
            , attribute "popovertarget" popoverTarget
            , class "list-row w-full p-0.5 grid grid-cols-[20px_auto_1fr_auto_24px] items-center gap-2 text-left"
            , css
                [ property "background" "none"
                , property "border" "none"
                , property "color" "inherit"
                , property "font" "inherit"
                , property "cursor" "pointer"
                , property "transition" "background-color 0.2s ease"
                , after [ property "border" "none" ]
                , hover [ property "background-color" "hsl(0 0% 100% / 0.05)" ]
                ]
            ]
            (carRowContent item)
        ]


carRowContent : StandingsEntry -> List (Html msg)
carRowContent item =
    [ div [ class "text-center text-xs" ] [ text (String.fromInt item.position) ]
    , CarStatus.carNumberBadgeRow item
    , div [ class "text-xs opacity-70" ]
        [ text (item.currentDriver |> Maybe.map (.name >> formatDriverName) |> Maybe.withDefault "") ]
    , div [ class "text-xs text-right" ]
        [ text (Gap.toString item.intervalToAhead) ]
    , if item.status == Car.InPit then
        div
            [ class "w-4 h-4 rounded-full border border-white-500 flex items-center justify-center text-white text-[9px] font-bold" ]
            [ text "P" ]

      else
        text ""
    ]
