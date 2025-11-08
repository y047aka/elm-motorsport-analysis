module Motorsport.Widget.LiveTimingControl exposing (view, Config)

{-| Live Timing Control Widget

This widget provides UI controls for Live Timing connection:

  - Connection status indicator
  - Connect/Disconnect button
  - Toggle switch for Live Timing

@docs view, Config

-}

import Html.Styled exposing (Html, button, div, span, text)
import Html.Styled.Attributes exposing (class, disabled, type_)
import Html.Styled.Events exposing (onClick)
import Motorsport.LiveTiming exposing (ConnectionStatus(..))


{-| Configuration for the Live Timing Control widget
-}
type alias Config msg =
    { connectionStatus : ConnectionStatus
    , liveTimingEnabled : Bool
    , onConnect : String -> msg
    , onDisconnect : msg
    , onToggle : msg
    , websocketUrl : String
    }


{-| Render the Live Timing Control widget
-}
view : Config msg -> Html msg
view config =
    div
        [ class "flex items-center gap-4 p-4 bg-base-200 rounded-lg shadow-md" ]
        [ statusIndicator config.connectionStatus
        , controlButtons config
        , toggleSwitch config
        ]


statusIndicator : ConnectionStatus -> Html msg
statusIndicator status =
    let
        ( statusColor, statusText, statusIcon ) =
            case status of
                Disconnected ->
                    ( "bg-error", "Disconnected", "●" )

                Connecting ->
                    ( "bg-warning", "Connecting...", "●" )

                Connected ->
                    ( "bg-success", "Connected", "●" )

                Reconnecting attempt ->
                    ( "bg-warning", "Reconnecting (" ++ String.fromInt attempt ++ ")...", "●" )

                Error msg ->
                    ( "bg-error", "Error: " ++ msg, "●" )
    in
    div
        [ class "flex items-center gap-2" ]
        [ span
            [ class ("inline-block w-3 h-3 rounded-full " ++ statusColor) ]
            [ text statusIcon ]
        , span
            [ class "text-sm font-medium" ]
            [ text statusText ]
        ]


controlButtons : Config msg -> Html msg
controlButtons config =
    case config.connectionStatus of
        Disconnected ->
            button
                [ class "btn btn-sm btn-primary"
                , onClick (config.onConnect config.websocketUrl)
                , disabled (not config.liveTimingEnabled)
                ]
                [ text "Connect" ]

        Connecting ->
            button
                [ class "btn btn-sm btn-disabled"
                , disabled True
                ]
                [ text "Connecting..." ]

        Connected ->
            button
                [ class "btn btn-sm btn-error"
                , onClick config.onDisconnect
                ]
                [ text "Disconnect" ]

        Reconnecting _ ->
            button
                [ class "btn btn-sm btn-warning"
                , onClick config.onDisconnect
                ]
                [ text "Cancel" ]

        Error _ ->
            button
                [ class "btn btn-sm btn-primary"
                , onClick (config.onConnect config.websocketUrl)
                , disabled (not config.liveTimingEnabled)
                ]
                [ text "Retry" ]


toggleSwitch : Config msg -> Html msg
toggleSwitch config =
    div
        [ class "form-control" ]
        [ div
            [ class "label cursor-pointer gap-2" ]
            [ span
                [ class "label-text text-sm" ]
                [ text "Live Timing" ]
            , Html.Styled.input
                [ type_ "checkbox"
                , class "toggle toggle-primary"
                , Html.Styled.Attributes.checked config.liveTimingEnabled
                , onClick config.onToggle
                ]
                []
            ]
        ]

