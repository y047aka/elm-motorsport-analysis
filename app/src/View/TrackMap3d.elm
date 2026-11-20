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
    , held : Bool
    , onGrab : Handle.Place -> msg
    , onMove : Handle.Place -> msg
    , onDrop : Handle.Place -> msg
    , onCancel : Int -> msg
    }


{-| The map, filling whatever box it is stood in, turned by a drag anywhere on it
and a step at a time by the arrow keys once it has the focus.
-}
surface : Config msg -> Html msg
surface ({ model, track, snapshot, size, label, keys } as config) =
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
         , attribute "aria-roledescription" "turnable map"
         ]
            ++ Handle.eventsAcross config
            ++ [ Handle.arrowKeys keys ]
        )
        [ Track3d.view size model track snapshot ]
