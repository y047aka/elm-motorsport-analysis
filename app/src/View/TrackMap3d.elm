module View.TrackMap3d exposing (Config, surface)

{-| The track map raised in space, and the surface a pointer is read on -- whether it turns
the map or carries the box is the page's.

The surface is a `drag-handle`: read without pointer capture, the drag stops the moment the
pointer leaves the card, which a turn round the lap does twice over.

@docs Config, surface

-}

import Drag.Handle as Handle
import Html exposing (Html)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (preventDefaultOn)
import Json.Decode as Decode
import Motorsport.Chart.Tracker exposing (Track)
import Motorsport.Chart.Tracker3d as Track3d exposing (Model)
import Motorsport.Race.Snapshot exposing (Snapshot)


{-| The page holds the way the map is looked at, and the box it is stood in: the drawing
is fitted to that box's proportions, in the page's own pixels. The view keeps nothing of
its own.
-}
type alias Config msg =
    { model : Model
    , track : Track
    , snapshot : Snapshot
    , size : { width : Float, height : Float }
    , label : String
    , keys : Handle.Steps -> msg
    , wheel : { x : Float, y : Float } -> msg
    , held : Bool
    , onGrab : Handle.Button -> Handle.Device -> Handle.Place -> msg
    , onMove : Handle.Place -> msg
    , onDrop : Handle.Place -> msg
    , onCancel : Int -> msg
    }


{-| The map, filling whatever box it is stood in, read through the pointer and the arrow
keys.
-}
surface : Config msg -> Html msg
surface ({ model, track, snapshot, size, label, keys, wheel } as config) =
    Html.node "drag-handle"
        ([ class
            ("absolute inset-0 grid touch-none select-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-ring "
                ++ (if config.held then
                        "cursor-grabbing"

                    else
                        "cursor-grab"
                   )
            )
         , attribute "tabindex" "0"
         , attribute "data-tracker-surface" ""
         , attribute "aria-label" label

         -- `application`, since a roledescription has to describe a role, and the keys this
         -- surface answers to are the surface's own and not the reader's.
         , attribute "role" "application"
         , attribute "aria-roledescription" "turnable map"
         ]
            ++ Handle.eventsByButton config
            ++ [ Handle.arrowKeys keys, scroll wheel ]
        )
        [ Track3d.view size model track snapshot ]


{-| The two-finger scroll, which turns the map the way the right button's drag does. Its
default is stopped, since the page behind the float would otherwise scroll under it.
-}
scroll : ({ x : Float, y : Float } -> msg) -> Html.Attribute msg
scroll toMsg =
    preventDefaultOn "wheel"
        (Decode.map2 (\x y -> ( toMsg { x = x, y = y }, True ))
            (Decode.field "deltaX" Decode.float)
            (Decode.field "deltaY" Decode.float)
        )
