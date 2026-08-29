module Main exposing (main)

{-| Drives the shadcn Select custom element from Elm.

`tick` exists to force unrelated re-renders: the app this is for redraws every
animation frame, so the question is not only whether the element works but
whether Elm re-sets its properties on every unrelated render. Watch
`window.__ceStats.optionsSets` while the counter runs.

-}

import Browser
import Html exposing (Html, button, div, h2, node, p, span, text)
import Html.Attributes exposing (class, property)
import Html.Events exposing (onClick)
import Html.Keyed
import Html.Lazy
import Json.Decode as Decode
import Json.Encode as Encode
import Time


type alias Model =
    { selected : Maybe String
    , tick : Int
    , ticking : Bool
    , useLazy : Bool
    , rotation : Int
    , presses : Int
    , mount : MountMode
    , cardFooter : Bool
    , cardMedia : Bool
    }


{-| Which of the two ways of drawing 62 badges is on screen.
-}
type MountMode
    = MountOff
    | MountCustomElements
    | MountPlainElm


type Msg
    = Selected String
    | Tick
    | ToggleTicking
    | ClearSelection
    | ToggleLazy
    | Rotate
    | Pressed
    | SetMount MountMode
    | ToggleCardFooter
    | ToggleCardMedia


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( { selected = Nothing, tick = 0, ticking = False, useLazy = True, rotation = 0, presses = 0, mount = MountOff, cardFooter = False, cardMedia = False }, Cmd.none )
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
        Selected value ->
            ( { model | selected = Just value }, Cmd.none )

        Tick ->
            ( { model | tick = model.tick + 1 }, Cmd.none )

        ToggleTicking ->
            ( { model | ticking = not model.ticking }, Cmd.none )

        ClearSelection ->
            ( { model | selected = Nothing }, Cmd.none )

        ToggleLazy ->
            ( { model | useLazy = not model.useLazy }, Cmd.none )

        Rotate ->
            ( { model | rotation = model.rotation + 1 }, Cmd.none )

        Pressed ->
            ( { model | presses = model.presses + 1 }, Cmd.none )

        SetMount mode ->
            ( { model | mount = mode }, Cmd.none )

        ToggleCardFooter ->
            ( { model | cardFooter = not model.cardFooter }, Cmd.none )

        ToggleCardMedia ->
            ( { model | cardMedia = not model.cardMedia }, Cmd.none )


options : List { value : String, label : String }
options =
    [ { value = "hypercar", label = "Hypercar" }
    , { value = "lmp2", label = "LMP2" }
    , { value = "lmgt3", label = "LMGT3" }
    ]


encodeOptions : List { value : String, label : String } -> Encode.Value
encodeOptions =
    Encode.list
        (\o ->
            Encode.object
                [ ( "value", Encode.string o.value )
                , ( "label", Encode.string o.label )
                ]
        )


view : Model -> Html Msg
view model =
    div [ class "dark min-h-screen bg-background text-foreground p-8 flex flex-col gap-6" ]
        [ h2 [ class "text-xl font-semibold" ] [ text "shadcn Select via a custom element" ]
        , div [ class "flex items-center gap-4" ]
            [ viewSelect model.useLazy model.selected
            , button
                [ onClick ClearSelection
                , class "rounded-md border border-input px-3 h-9 text-sm"
                ]
                [ text "Clear from Elm" ]
            ]
        , p [ class "text-sm" ]
            [ text "Elm holds: "
            , span [ class "font-mono", Html.Attributes.id "elm-state" ]
                [ text (Maybe.withDefault "(nothing)" model.selected) ]
            ]
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
            , button
                [ onClick ToggleLazy
                , class "rounded-md border border-input px-3 h-9 text-sm"
                ]
                [ text
                    (if model.useLazy then
                        "lazy: ON"

                     else
                        "lazy: OFF"
                    )
                ]
            ]
        , viewCards model
        , viewMountBench model.mount
        , viewSlottedButton model.presses
        , viewKeyedProbes model.rotation
        ]


{-| Three ways of putting Elm's content inside shadcn's Card, drawn from the
same children. Card's padding is conditional on what it contains, so the
strip at the bottom of the page says which of the three Card can see.
-}
viewCards : Model -> Html Msg
viewCards model =
    div [ class "flex flex-col gap-3" ]
        [ div [ class "flex items-center gap-2" ]
            [ button
                [ onClick ToggleCardFooter
                , Html.Attributes.attribute "data-card" "footer"
                , class "rounded-md border border-input px-3 h-8 text-xs"
                ]
                [ text
                    (if model.cardFooter then
                        "footer: ON"

                     else
                        "footer: OFF"
                    )
                ]
            , button
                [ onClick ToggleCardMedia
                , Html.Attributes.attribute "data-card" "media"
                , class "rounded-md border border-input px-3 h-8 text-xs"
                ]
                [ text
                    (if model.cardMedia then
                        "leading image: ON"

                     else
                        "leading image: OFF"
                    )
                ]
            ]
        , div [ class "grid grid-cols-3 gap-4 items-start" ]
            [ node "card-slotted"
                [ Html.Attributes.id "a2" ]
                (cardParts model)
            , node "card-named-slots"
                [ Html.Attributes.id "a1"
                , property "footer" (Encode.bool model.cardFooter)
                ]
                (namedSlotParts model)
            , node "card-plain"
                [ Html.Attributes.id "b" ]
                (cardParts model)
            ]
        ]


{-| The same markup for A2 and B: only the element wrapping it differs.
-}
cardParts : Model -> List (Html Msg)
cardParts model =
    List.concat
        [ if model.cardMedia then
            [ Html.img [ Html.Attributes.src mediaSrc, class "h-16 w-full object-cover" ] [] ]

          else
            []
        , [ node "card-plain-header"
                []
                [ node "card-plain-title" [] [ text "6 Hours of Imola" ] ]
          , node "card-plain-content" [] [ text "Elm renders this." ]
          ]
        , if model.cardFooter then
            [ node "card-plain-footer" [] [ text "footer" ] ]

          else
            []
        ]


namedSlotParts : Model -> List (Html Msg)
namedSlotParts model =
    List.concat
        [ if model.cardMedia then
            [ Html.img
                [ Html.Attributes.src mediaSrc
                , Html.Attributes.attribute "slot" "media"
                , class "h-16 w-full object-cover"
                ]
                []
            ]

          else
            []
        , [ span [ Html.Attributes.attribute "slot" "title" ] [ text "6 Hours of Imola" ]
          , span [ Html.Attributes.attribute "slot" "content" ] [ text "Elm renders this." ]
          ]
        , if model.cardFooter then
            [ span [ Html.Attributes.attribute "slot" "footer" ] [ text "footer" ] ]

          else
            []
        ]


{-| A one-pixel image, inlined so the measurement never waits on the network.
-}
mediaSrc : String
mediaSrc =
    "data:image/gif;base64,R0lGODlhAQABAIAAAFmZzAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="


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


{-| The label is Elm-rendered content inside a shadow-root component, and it
changes on every press: if the two virtual DOMs contended for those nodes, this
is where it would show.
-}
viewSlottedButton : Int -> Html Msg
viewSlottedButton presses =
    div [ class "flex items-center gap-4" ]
        [ node "shadcn-button"
            [ Html.Attributes.attribute "variant" "outline"
            , Html.Attributes.attribute "size" "sm"

            -- React's synthetic onClick never sees a click on slotted
            -- content, so the native event on the host is what Elm listens to.
            , onClick Pressed
            ]
            [ span [ class "font-mono" ] [ text ("pressed " ++ String.fromInt presses) ]
            , span [ class "opacity-60" ] [ text " · slotted from Elm" ]
            ]
        , span [ class "text-sm" ] [ text "children come from Elm, chrome from React" ]
        ]


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


{-| `options` never changes, so it is passed through `lazy` to find out whether
that is enough to stop Elm from re-setting the property on unrelated renders.
-}
viewSelect : Bool -> Maybe String -> Html Msg
viewSelect useLazy selected =
    if useLazy then
        Html.Lazy.lazy selectNode selected

    else
        selectNode selected


selectNode : Maybe String -> Html Msg
selectNode selected =
    node "shadcn-select"
        [ property "options" (encodeOptions options)
        , property "value"
            (case selected of
                Just v ->
                    Encode.string v

                Nothing ->
                    Encode.null
            )
        , property "placeholder" (Encode.string "Pick a class…")
        , Html.Events.on "value-change"
            (Decode.map Selected (Decode.at [ "detail" ] Decode.string))
        ]
        []
