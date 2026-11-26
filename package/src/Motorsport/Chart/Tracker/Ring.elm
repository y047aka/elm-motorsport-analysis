module Motorsport.Chart.Tracker.Ring exposing (view)

{-| The track as the summary's proportions describe it: a ring, run clockwise from the finish line at 12 o'clock, each stretch taking the share of the circle its share of the lap gives it, and each car placed by the share of its lap's time it has run.

@docs view

-}

import Angle exposing (Angle)
import Motorsport.Chart.Tracker.Config as Config exposing (MiniSectorShares(..), TrackConfig)
import Motorsport.Chart.Tracker.Detail exposing (Detail(..), Labels(..))
import Motorsport.Chart.Tracker.Marker as Marker
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.LeMans as LeMans
import Motorsport.Wec.Class as Class
import Scale exposing (ContinuousScale)
import Svg exposing (Svg, circle, g, line, svg, text, text_)
import Svg.Attributes exposing (class, dominantBaseline, fill, stroke, textAnchor)
import Svg.Keyed as Keyed
import Svg.Lazy as Lazy
import TypedSvg.Attributes as Attributes exposing (strokeWidth, viewBox, x1, x2, y1, y2)
import TypedSvg.Types exposing (Transform(..), px)


{-| A share of the lap (0-1) as an angle, round from 12 o'clock.
-}
angleAt : Float -> Angle
angleAt progress =
    Angle.radians (Scale.convert clockwise progress)


{-| A share of the lap (0-1) as an angle in radians, round from 12 o'clock.
-}
clockwise : ContinuousScale Float
clockwise =
    Scale.linear ( -pi / 2, -pi / 2 + 2 * pi ) ( 0, 1 )


type alias Constants =
    { viewBox : { w : Float, h : Float }
    , track :
        { cx : Float
        , cy : Float
        , r : Float
        , trackWidth : Float
        , startFinishLineExtension : Float
        , startFinishLineStrokeWidth : Float
        , sectorBoundaryOffset : Float
        , sectorBoundaryStrokeWidth : Float
        }
    , car : { size : Float }
    , labels : Labels
    }


constants : Detail -> Constants
constants detail =
    case detail of
        Compact ->
            let
                -- No wider than the field drawn on the circle.
                size =
                    540
            in
            { viewBox = { w = size, h = size }
            , track =
                { cx = size / 2
                , cy = size / 2
                , r = 250
                , trackWidth = 2
                , startFinishLineExtension = 12
                , startFinishLineStrokeWidth = 3
                , sectorBoundaryOffset = 10
                , sectorBoundaryStrokeWidth = 4
                }
            , car = { size = 10 }
            , labels = NoLabels
            }

        Full ->
            let
                -- Wide enough for the sector labels outside the circle, and
                -- the font they are drawn in.
                size =
                    630
            in
            { viewBox = { w = size, h = size }
            , track =
                { cx = size / 2
                , cy = size / 2
                , r = 250
                , trackWidth = 1.5
                , startFinishLineExtension = 15
                , startFinishLineStrokeWidth = 2
                , sectorBoundaryOffset = 10
                , sectorBoundaryStrokeWidth = 3
                }
            , car = { size = 9 }
            , labels =
                Labels
                    { sectorRadius = 300
                    , sectorFontSize = 16
                    , miniSectorRadius = 230
                    , miniSectorFontSize = 12
                    , carRadius = 270
                    , carFontSize = 13
                    }
            }


{-| The chart fills whatever box it is given, proportions and all -- so a box whose height is sized by its content is sized by this drawing, not the other way round. Settling the box first is the caller's work.
-}
view : Detail -> TrackConfig -> Snapshot -> Svg msg
view detail config standings =
    let
        { w, h } =
            (constants detail).viewBox
    in
    svg
        [ viewBox 0 0 w h
        , class "h-full w-full"
        ]
        [ Lazy.lazy2 track detail config
        , renderCars detail config standings
        ]


track : Detail -> TrackConfig -> Svg msg
track detail config =
    let
        c =
            constants detail

        { cx, cy, r, trackWidth } =
            c.track

        trackCircle color width =
            circle
                [ Attributes.cx (px cx)
                , Attributes.cy (px cy)
                , Attributes.r (px r)
                , fill "none"
                , stroke color
                , strokeWidth (px width)
                ]
                []

        outerTrackCircle =
            trackCircle "oklch(1 0 0 / 0.2)" trackWidth

        startFinishLine =
            line
                [ x1 (px cx)
                , y1 (px (cy - r - c.track.startFinishLineExtension))
                , x2 (px cx)
                , y2 (px (cy - r + c.track.startFinishLineExtension))
                , stroke "#fff"
                , strokeWidth (px c.track.startFinishLineStrokeWidth)
                ]
                []

        makeBoundary angle =
            line
                [ x1 (px (cx + (r - c.track.sectorBoundaryOffset) * Angle.cos angle))
                , y1 (px (cy + (r - c.track.sectorBoundaryOffset) * Angle.sin angle))
                , x2 (px (cx + (r + c.track.sectorBoundaryOffset) * Angle.cos angle))
                , y2 (px (cy + (r + c.track.sectorBoundaryOffset) * Angle.sin angle))
                , stroke "oklch(0.23 0 0)"
                , strokeWidth (px c.track.sectorBoundaryStrokeWidth)
                ]
                []

        boundaries =
            Config.boundaries config
                |> List.map angleAt
                |> List.map (\angle -> makeBoundary angle)

        sectorLabels =
            renderSectorLabels detail config

        miniSectorLabels =
            renderMiniSectorLabels detail config
    in
    g [] (outerTrackCircle :: boundaries ++ startFinishLine :: sectorLabels ++ miniSectorLabels)


renderSectorLabels : Detail -> TrackConfig -> List (Svg msg)
renderSectorLabels detail config =
    case (constants detail).labels of
        NoLabels ->
            []

        Labels { sectorRadius, sectorFontSize } ->
            config.sectors
                |> Sector.toList
                |> List.map
                    (\( sector, { start, share } ) ->
                        makeLabel detail
                            { progress = start + (share / 2)
                            , radius = sectorRadius
                            , fontSize = sectorFontSize
                            , color = "oklch(1 0 0 / 0.5)"
                            , label = Sector.toString sector
                            }
                    )


renderMiniSectorLabels : Detail -> TrackConfig -> List (Svg msg)
renderMiniSectorLabels detail config =
    case ( (constants detail).labels, config.miniSectors ) of
        ( NoLabels, _ ) ->
            []

        ( _, NoMiniSectors ) ->
            []

        ( Labels { miniSectorRadius, miniSectorFontSize }, MiniSectorShares shares ) ->
            shares
                |> LeMans.toList
                |> List.map
                    (\( mini, { start, share } ) ->
                        makeLabel detail
                            -- At the end of the mini-sector, not the middle of
                            -- it as a sector's label is: fifteen of them round
                            -- one circle leaves no room to centre them in.
                            { progress = start + share
                            , radius = miniSectorRadius
                            , fontSize = miniSectorFontSize
                            , color = "oklch(0.5 0 0)"
                            , label = LeMans.toString mini
                            }
                    )


makeLabel :
    Detail
    ->
        { progress : Float
        , radius : Float
        , fontSize : Float
        , color : String
        , label : String
        }
    -> Svg msg
makeLabel detail { progress, radius, fontSize, color, label } =
    let
        { cx, cy } =
            (constants detail).track

        angle =
            angleAt progress

        labelX =
            cx + radius * Angle.cos angle

        labelY =
            cy + radius * Angle.sin angle
    in
    text_
        [ Attributes.x (px labelX)
        , Attributes.y (px labelY)
        , Attributes.fontSize (px fontSize)
        , textAnchor "middle"
        , dominantBaseline "central"
        , fill color
        ]
        [ text label ]


renderCars : Detail -> TrackConfig -> Snapshot -> Svg msg
renderCars detail config standings =
    Keyed.node "g"
        []
        (Snapshot.toList standings
            |> List.reverse
            |> List.map
                (\car ->
                    ( car.metadata.carNumber
                    , Lazy.lazy3 renderCarOnTrack detail config car
                    )
                )
        )


renderCarOnTrack : Detail -> TrackConfig -> CarAt -> Svg msg
renderCarOnTrack detail config car =
    let
        coords =
            coordinatesOnTrack detail config car
    in
    renderCar detail car coords


coordinatesOnTrack : Detail -> TrackConfig -> CarAt -> { angle : Angle, x : Float, y : Float }
coordinatesOnTrack detail config car =
    let
        { cx, cy, r } =
            (constants detail).track

        progress =
            Config.progressOf config car

        angle =
            angleAt progress
    in
    { angle = angle
    , x = cx + r * Angle.cos angle
    , y = cy + r * Angle.sin angle
    }


renderCar : Detail -> CarAt -> { angle : Angle, x : Float, y : Float } -> Svg msg
renderCar detail car { angle, x, y } =
    let
        c =
            constants detail

        { cx, cy } =
            c.track

        marker =
            g [ Attributes.transform [ Translate x y ] ]
                [ Lazy.lazy3 Marker.dot c.car.size car.standing.positionInClass (Class.toColor car.metadata.class) ]
    in
    case c.labels of
        NoLabels ->
            marker

        Labels { carRadius, carFontSize } ->
            g []
                [ marker
                , Marker.number carFontSize
                    car.standing.positionInClass
                    { x = cx + carRadius * Angle.cos angle, y = cy + carRadius * Angle.sin angle }
                    { carNumber = car.metadata.carNumber }
                ]
