module Page.Wec.Float exposing (Model, Msg(..), Out(..), init, update, view, toggle)

{-| The track map floated over the columns: hidden until the tracker column's `◱`
asks for it, sized by a grip along each of its two inner edges, carried by a third, and taking part in none of the strip's grid.

The camera belongs here: this is the one drawing raised off the ground it was surveyed on.

@docs Model, Msg, Out, init, update, view, toggle

-}

import Drag.Handle as Handle
import Html exposing (Html, div, text)
import Html.Attributes as Attributes exposing (attribute)
import Motorsport.Chart.Tracker exposing (Track)
import Motorsport.Chart.Tracker3d as Track3d
import Motorsport.Race.Snapshot exposing (Snapshot)
import Page.Wec.Columns as Columns
import Page.Wec.Resize as Resize
import Page.Wec.Shift as Shift
import View.CarDetail.Header as Header
import View.TrackMap3d as TrackMap3d


type alias Model =
    { shown : Bool
    , width : Resize.Model
    , height : Resize.Model
    , shift : Shift.Model
    , camera : Track3d.Model
    }


init : Model
init =
    { shown = False
    , width = Resize.init defaultWidth
    , height = Resize.init defaultHeight
    , shift = Shift.init
    , camera = Track3d.init
    }


type Msg
    = Toggle
    | WidthMsg Resize.Msg
    | HeightMsg Resize.Msg
    | ShiftMsg Shift.Msg
    | CameraMsg Track3d.Msg


{-| What an `update` leaves for the page. The only press that opens the map stands
in the tracker column's corner, and the reader can close that column: opening the
map opens the column back, or the feature has gone missing.
-}
type Out
    = None
    | Send (Cmd Msg)
    | OpenTrackerColumn


{-| The box the floating map opens at.
480 by 180 is `Tracker3d.box`'s own three to one once the card's 32px of padding is gone, and a box of that shape is the one the drawing fills exactly; letterboxing is what a box of another proportion costs.
The map is stood at the bottom right of the page and grows up and left, so both grips are `AgainstPointer`: a travel away from the corner it is anchored to is what makes it bigger.
-}
defaultWidth : Float
defaultWidth =
    480


defaultHeight : Float
defaultHeight =
    180


widthFence : Resize.Fence
widthFence =
    { min = 280
    , max = 960
    , step = 20
    }


heightFence : Resize.Fence
heightFence =
    { min = 120
    , max = 480
    , step = 20
    }


widthEdge : Resize.Edge
widthEdge =
    { axis = Handle.Across
    , grows = Resize.AgainstPointer
    , fence = widthFence
    , id = "tracker-float-width-grip"
    , label = "Resize the floating track map's width"
    }


heightEdge : Resize.Edge
heightEdge =
    { axis = Handle.Down
    , grows = Resize.AgainstPointer
    , fence = heightFence
    , id = "tracker-float-height-grip"
    , label = "Resize the floating track map's height"
    }


{-| `boxId` is what the travel is measured against at every pick.
-}
box : Shift.Box
box =
    { boxId = "tracker-float-box"
    , gripId = "tracker-float-move-grip"
    , label = "Move the floating track map"
    }


update : Msg -> Model -> ( Model, Out )
update msg m =
    case msg of
        Toggle ->
            if m.shown then
                ( { m | shown = False }, None )

            else
                ( { m | shown = True }, OpenTrackerColumn )

        WidthMsg sub ->
            ( { m | width = Resize.update widthEdge sub m.width }, None )

        HeightMsg sub ->
            ( { m | height = Resize.update heightEdge sub m.height }, None )

        ShiftMsg sub ->
            let
                ( shift, cmd ) =
                    Shift.update box sub m.shift
            in
            ( { m | shift = shift }, Send (Cmd.map ShiftMsg cmd) )

        CameraMsg sub ->
            ( { m | camera = Track3d.update sub m.camera }, None )


{-| The map floated over the columns, drawn into the card the page hands it. Nothing
is drawn while the map is hidden.

It is a child of `mainGrid` and not of the strip: the strip scrolls sideways, and anything absolutely placed inside one is placed against its scrollport and travels with it. Its offsets are read against `mainGrid`'s padding box, so `bottom-2.5 right-2.5` is what stands it on the same edge the columns end at. `z-40` is what a carried column's `z-30` needs to be under, and `card-elements.ts` owns every class the card itself has, which leaves the wrapper the one thing here that can carry a surface.

-}
view : Model -> (Html Msg -> List (Html Msg) -> Html Msg) -> Track -> Snapshot -> Html Msg
view m frame track snapshot =
    if not m.shown then
        text ""

    else
        div
            [ Attributes.id box.boxId
            , Attributes.class "absolute bottom-2.5 right-2.5 z-40 grid rounded-xl bg-background/80 text-popover-foreground backdrop-blur-lg border border-border shadow-glass"
            , Attributes.style "width" (Columns.px m.width.size)
            , Attributes.style "height" (Columns.px m.height.size)
            , Attributes.style "transform" ("translate(" ++ Columns.px m.shift.x ++ ", " ++ Columns.px m.shift.y ++ ")")
            , attribute "data-tracker-float" ""
            ]
            [ frame (surface m track snapshot)
                [ Html.map ShiftMsg (Shift.handle box m.shift), toggle True ]
            , div [ Attributes.class "absolute -left-2.5 top-0 z-10 grid h-full w-2.5 place-items-center" ]
                [ Html.map WidthMsg (Resize.grip widthEdge m.width) ]
            , div [ Attributes.class "absolute -top-2.5 left-0 z-10 grid h-2.5 w-full place-content-center" ]
                [ Html.map HeightMsg (Resize.grip heightEdge m.height) ]
            ]


surface : Model -> Track -> Snapshot -> Html Msg
surface m track snapshot =
    TrackMap3d.surface { model = m.camera, toMsg = CameraMsg, track = track, snapshot = snapshot }


{-| The press that floats the map over the columns: `◱` while it is hidden, the ✕ every overlay here closes with once it is shown.

It is drawn twice when the map is up -- in the column the press came from, and in
the corner of the map itself -- so the way back is wherever the room was asked from.

-}
toggle : Bool -> Html Msg
toggle shown =
    let
        ( glyph, label ) =
            if shown then
                ( "✕", "Close the floating track map" )

            else
                ( "◱", "Float the track map over the columns" )
    in
    Header.cornerButton { onPress = Toggle, label = label, glyph = glyph }
