module Main exposing (main)

{-| Drives `ce-probe` from Elm, in the three shapes it is measured in: many at
once, reordered, and left alone while the model changes.

`tick` exists to force unrelated re-renders: the app this is for redraws every
animation frame, so the question is not only whether an element works but
whether Elm re-sets its properties on every unrelated render. Watch the
`react renders` counter while it runs.

-}

import Browser
import Html exposing (Html, button, div, h2, node, span, text)
import Html.Attributes exposing (class, property)
import Html.Events exposing (onClick)
import Html.Keyed
import Json.Encode as Encode
import Time


type alias Model =
    { tick : Int
    , ticking : Bool
    , rotation : Int
    , mount : MountMode
    }


{-| Which of the two ways of drawing 62 badges is on screen.
-}
type MountMode
    = MountOff
    | MountCustomElements
    | MountPlainElm


type Msg
    = Tick
    | ToggleTicking
    | Rotate
    | SetMount MountMode


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( { tick = 0, ticking = False, rotation = 0, mount = MountOff }, Cmd.none )
        , update = update
        , subscriptions =
            \m ->
                if m.ticking then
                    Time.every 20 (always Tick)

                else
                    Sub.none
        , view = view
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick ->
            ( { model | tick = model.tick + 1 }, Cmd.none )

        ToggleTicking ->
            ( { model | ticking = not model.ticking }, Cmd.none )

        Rotate ->
            ( { model | rotation = model.rotation + 1 }, Cmd.none )

        SetMount mode ->
            ( { model | mount = mode }, Cmd.none )


view : Model -> Html Msg
view model =
    div [ class "min-h-screen bg-background text-foreground p-8 flex flex-col gap-6" ]
        [ h2 [ class "text-xl font-semibold" ] [ text "custom element lifecycle probe" ]
        , div [ class "flex items-center gap-4" ]
            [ button
                [ onClick ToggleTicking
                , class "rounded-md border border-input px-3 h-9 text-sm"
                ]
                [ text
                    (if model.ticking then
                        "Stop re-rendering"

                     else
                        "Re-render every frame"
                    )
                ]
            , span [ class "text-sm font-mono", Html.Attributes.id "tick" ]
                [ text ("tick " ++ String.fromInt model.tick) ]
            ]
        , viewMountBench model.mount
        , viewKeyedProbes model.rotation
        ]


{-| 62 badges, the size the standings list runs at, drawn either as custom
elements with a React root each or as plain Elm nodes. `mount-bench.ts` times
the click through to the frame the nodes are laid out in.
-}
viewMountBench : MountMode -> Html Msg
viewMountBench mode =
    div [ class "flex flex-col gap-2" ]
        [ div [ class "flex items-center gap-2" ]
            [ benchButton "custom elements" MountCustomElements
            , benchButton "plain elm" MountPlainElm
            , benchButton "off" MountOff
            ]
        , div [ Html.Attributes.id "bench-list", class "flex flex-wrap gap-1" ] (mountedBadges mode)
        ]


benchButton : String -> MountMode -> Html Msg
benchButton label mode =
    button
        [ onClick (SetMount mode)
        , Html.Attributes.attribute "data-bench" label
        , class "rounded-md border border-input px-3 h-8 text-xs"
        ]
        [ text label ]


mountedBadges : MountMode -> List (Html Msg)
mountedBadges mode =
    case mode of
        MountOff ->
            []

        MountCustomElements ->
            List.range 0 61
                |> List.map
                    (\i ->
                        node "ce-probe"
                            [ property "label" (Encode.string ("#" ++ String.fromInt i)) ]
                            []
                    )

        MountPlainElm ->
            List.range 0 61
                |> List.map
                    (\i ->
                        span
                            [ Html.Attributes.attribute "data-bench-probe" ""
                            , class "inline-flex h-5 items-center rounded-4xl border border-border px-2 text-xs"
                            ]
                            [ text ("#" ++ String.fromInt i) ]
                    )


{-| Mirrors how the standings list reorders: the same keys in a different
order, so Elm moves the existing nodes rather than building new ones.
-}
viewKeyedProbes : Int -> Html Msg
viewKeyedProbes rotation =
    let
        keys =
            List.range 0 11

        rotated =
            List.drop (modBy 12 rotation) keys ++ List.take (modBy 12 rotation) keys
    in
    div [ class "flex flex-col gap-3" ]
        [ button
            [ onClick Rotate
            , class "self-start rounded-md border border-input px-3 h-9 text-sm"
            ]
            [ text ("Reorder keyed list (" ++ String.fromInt rotation ++ ")") ]
        , Html.Keyed.node "div"
            [ class "flex flex-wrap gap-2" ]
            (List.map
                (\i ->
                    ( String.fromInt i
                    , node "ce-probe"
                        [ property "label" (Encode.string ("car " ++ String.fromInt i)) ]
                        []
                    )
                )
                rotated
            )
        ]
