module View.TrackMap3d exposing (Config, surface)

{-| The track map raised in space and the pointer that turns it.

The surface is a `drag-handle`: turned without pointer capture, the map stops the
moment the pointer leaves the card -- which a turn round the lap does, twice.

@docs Config, surface

-}

import Html exposing (Html)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (on, preventDefaultOn)
import Json.Decode as Decode exposing (Decoder)
import Motorsport.Chart.Tracker exposing (Track)
import Motorsport.Chart.Tracker3d as Track3d exposing (Model, Msg)
import Motorsport.Race.Snapshot exposing (Snapshot)


{-| The page holds the way the map is looked at, and the box it is stood in: the drawing
is fitted to that box's proportions, in the page's own pixels. The view keeps nothing of
its own.
-}
type alias Config msg =
    { model : Model
    , toMsg : Msg -> msg
    , track : Track
    , snapshot : Snapshot
    , size : { width : Float, height : Float }
    }


{-| The map, filling whatever box it is stood in, turned by a drag anywhere on it
and a step at a time by the arrow keys once it has the focus.
-}
surface : Config msg -> Html msg
surface { model, toMsg, track, snapshot, size } =
    Html.node "drag-handle"
        ([ class
            ("absolute inset-0 grid touch-none select-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-ring "
                ++ (if dragging model then
                        "cursor-grabbing"

                    else
                        "cursor-grab"
                   )
            )
         , attribute "tabindex" "0"
         , attribute "aria-label" "Turn the track map: drag it, or press the arrow keys"
         , attribute "aria-roledescription" "turnable map"
         , on "pointerdown" (press toMsg)
         , on "pointerup" (Decode.succeed (toMsg Track3d.Release))
         , on "pointercancel" (Decode.succeed (toMsg Track3d.Cancel))
         , on "lostpointercapture" (Decode.succeed (toMsg Track3d.Cancel))
         , preventDefaultOn "keydown" (keys toMsg)
         ]
            ++ moves toMsg model
        )
        [ Track3d.view size model track snapshot ]


dragging : Model -> Bool
dragging model =
    model.drag /= Nothing


moves : (Msg -> msg) -> Model -> List (Html.Attribute msg)
moves toMsg model =
    if dragging model then
        [ on "pointermove"
            (Decode.map2 (\x y -> toMsg (Track3d.Turn x y)) (coordinate "clientX") (coordinate "clientY"))
        ]

    else
        []


press : (Msg -> msg) -> Decoder msg
press toMsg =
    Decode.field "button" Decode.int
        |> Decode.andThen
            (\button ->
                if button == 0 then
                    Decode.map2 (\x y -> toMsg (Track3d.Grab x y)) (coordinate "clientX") (coordinate "clientY")

                else
                    Decode.fail "not the primary button"
            )


coordinate : String -> Decoder Float
coordinate name =
    Decode.field name Decode.float


keys : (Msg -> msg) -> Decoder ( msg, Bool )
keys toMsg =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                case key of
                    "ArrowLeft" ->
                        Decode.succeed ( toMsg (Track3d.Step (negate keyStep) 0), True )

                    "ArrowRight" ->
                        Decode.succeed ( toMsg (Track3d.Step keyStep 0), True )

                    "ArrowUp" ->
                        Decode.succeed ( toMsg (Track3d.Step 0 keyStep), True )

                    "ArrowDown" ->
                        Decode.succeed ( toMsg (Track3d.Step 0 (negate keyStep)), True )

                    _ ->
                        Decode.succeed ( toMsg (Track3d.Step 0 0), False )
            )


keyStep : Float
keyStep =
    degrees 5
