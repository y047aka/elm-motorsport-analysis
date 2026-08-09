module Motorsport.Chart.Tracker exposing (Track, empty, fromConfig, view)

{-| The field drawn going round the circuit.

@docs Track, empty, fromConfig, view

-}

import Css
import Motorsport.Chart.Tracker.Config as Config exposing (TrackConfig)
import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.LeMans as LeMans
import Motorsport.Wec.Class as Class
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, circle, g, line, svg, text, text_)
import Svg.Styled.Attributes exposing (css, dominantBaseline, fill, stroke, textAnchor)
import Svg.Styled.Keyed as Keyed
import Svg.Styled.Lazy as Lazy
import TypedSvg.Styled.Attributes as Attributes exposing (fontSize, strokeWidth, viewBox, x1, x2, y1, y2)
import TypedSvg.Types exposing (Transform(..), px)


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
        , sectorLabelRadius : Float
        , sectorLabelFontSize : Float
        , miniSectorLabelRadius : Float
        , miniSectorLabelFontSize : Float
        }
    , car :
        { size : Float
        , labelRadius : Float
        , labelFontSize : Float
        }
    }


constants : Constants
constants =
    let
        viewBoxWidth =
            800

        viewBoxHeight =
            600
    in
    { viewBox = { w = viewBoxWidth, h = viewBoxHeight }
    , track =
        { cx = viewBoxWidth / 2
        , cy = viewBoxHeight / 2
        , r = 250
        , trackWidth = 4
        , startFinishLineExtension = 15
        , startFinishLineStrokeWidth = 2
        , sectorBoundaryOffset = 10
        , sectorBoundaryStrokeWidth = 3
        , sectorLabelRadius = 300
        , sectorLabelFontSize = 16
        , miniSectorLabelRadius = 230
        , miniSectorLabelFontSize = 10
        }
    , car =
        { size = 8
        , labelRadius = 270
        , labelFontSize = 12
        }
    }


{-| Scale function converting a track progress value (0-1) into an angle (radians).
Depending on rotation direction, maps to 0-2π clockwise or counter-clockwise from the 12 o'clock position.
-}
progressToAngleScale : Direction -> ContinuousScale Float
progressToAngleScale direction =
    let
        quarterTurn =
            pi / 2
    in
    case direction of
        Clockwise ->
            -- Map to 0-2π clockwise from the 12 o'clock position
            Scale.linear ( -quarterTurn, -quarterTurn + 2 * pi ) ( 0, 1 )

        CounterClockwise ->
            -- Map to 0-2π counter-clockwise from the 12 o'clock position
            Scale.linear ( -quarterTurn, -quarterTurn - 2 * pi ) ( 0, 1 )


{-| The circuit, drawn to the proportions the race ended up with. See
[`fromConfig`](#fromConfig).
-}
type Track
    = Track
        { direction : Direction
        , config : TrackConfig
        }


{-| The track as the summary describes it, plus which way the cars go round.
Hold on to the result and hand it to [`view`](#view) each frame.

The proportions are the race's _final_ records, not the ones standing at some
moment of it: a sector's share of the lap is how quick it was at its quickest,
and mid-race that answer is still moving. That the CLI reads them off the whole
file is what makes the track the same shape from the first frame to the last.

-}
fromConfig : { direction : Direction, config : TrackConfig } -> Track
fromConfig =
    Track


{-| The track to stand in for one whose race has not loaded yet: the lap divided
in three even stretches, which is what a summary that has said nothing about the
circuit leaves to draw. Written out rather than worked out -- the rule that
divides a lap lives in the CLI now, and three thirds do not need it.
-}
empty : Track
empty =
    Track
        { direction = Clockwise
        , config =
            { sectors =
                { s1 = { start = 0, share = 1 / 3 }
                , s2 = { start = 1 / 3, share = 1 / 3 }
                , s3 = { start = 2 / 3, share = 1 / 3 }
                }
            , miniSectors = Config.NoMiniSectors
            }
        }


view : Track -> Snapshot -> Svg msg
view (Track { direction, config }) standings =
    viewWithConfig direction config standings


viewWithConfig : Direction -> TrackConfig -> Snapshot -> Svg msg
viewWithConfig direction config standings =
    let
        { w, h } =
            constants.viewBox
    in
    svg
        [ viewBox 0 0 w h
        , css [ Css.maxWidth (Css.pct 100), Css.maxHeight (Css.pct 90) ]
        ]
        [ Lazy.lazy2 track direction config
        , renderCars direction config standings
        ]


track : Direction -> TrackConfig -> Svg msg
track direction config =
    let
        { cx, cy, r, trackWidth } =
            constants.track

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
            trackCircle "oklch(1 0 0 / 0.2)" 1

        startFinishLine =
            line
                [ x1 (px cx)
                , y1 (px (cy - r - constants.track.startFinishLineExtension))
                , x2 (px cx)
                , y2 (px (cy - r + constants.track.startFinishLineExtension))
                , stroke "#fff"
                , strokeWidth (px constants.track.startFinishLineStrokeWidth)
                ]
                []

        makeBoundary angle =
            line
                [ x1 (px (cx + (r - constants.track.sectorBoundaryOffset) * cos angle))
                , y1 (px (cy + (r - constants.track.sectorBoundaryOffset) * sin angle))
                , x2 (px (cx + (r + constants.track.sectorBoundaryOffset) * cos angle))
                , y2 (px (cy + (r + constants.track.sectorBoundaryOffset) * sin angle))
                , stroke "oklch(0.23 0 0)"
                , strokeWidth (px constants.track.sectorBoundaryStrokeWidth)
                ]
                []

        boundaries =
            Config.calcSectorBoundaries config
                |> List.map (Scale.convert (progressToAngleScale direction))
                |> List.map (\angle -> makeBoundary angle)

        sectorLabels =
            renderSectorLabels direction config

        miniSectorLabels =
            renderMiniSectorLabels direction config
    in
    g [] (outerTrackCircle :: boundaries ++ startFinishLine :: sectorLabels ++ miniSectorLabels)


renderSectorLabels : Direction -> TrackConfig -> List (Svg msg)
renderSectorLabels direction config =
    config.sectors
        |> Sector.toList
        |> List.map
            (\( sector, { start, share } ) ->
                makeLabel direction
                    { progress = start + (share / 2)
                    , radius = constants.track.sectorLabelRadius
                    , fontSize = constants.track.sectorLabelFontSize
                    , color = "oklch(1 0 0 / 0.5)"
                    , label = Sector.toString sector
                    }
            )


renderMiniSectorLabels : Direction -> TrackConfig -> List (Svg msg)
renderMiniSectorLabels direction config =
    case config.miniSectors of
        Config.NoMiniSectors ->
            []

        Config.MiniSectorShares shares ->
            shares
                |> LeMans.toList
                |> List.map
                    (\( mini, { start, share } ) ->
                        makeLabel direction
                            -- At the end of the mini-sector, not the middle of
                            -- it as a sector's label is: fifteen of them round
                            -- one circle leaves no room to centre them in.
                            { progress = start + share
                            , radius = constants.track.miniSectorLabelRadius
                            , fontSize = constants.track.miniSectorLabelFontSize
                            , color = "oklch(0.5 0 0)"
                            , label = LeMans.toString mini
                            }
                    )


makeLabel :
    Direction
    ->
        { progress : Float
        , radius : Float
        , fontSize : Float
        , color : String
        , label : String
        }
    -> Svg msg
makeLabel direction { progress, radius, fontSize, color, label } =
    let
        { cx, cy } =
            constants.track

        angle =
            Scale.convert (progressToAngleScale direction) progress

        labelX =
            cx + radius * cos angle

        labelY =
            cy + radius * sin angle
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


renderCars : Direction -> TrackConfig -> Snapshot -> Svg msg
renderCars direction config standings =
    Keyed.node "g"
        []
        (Snapshot.toList standings
            |> List.reverse
            |> List.map
                (\car ->
                    ( car.metadata.carNumber
                    , Lazy.lazy3 renderCarOnTrack direction config car
                    )
                )
        )


renderCarOnTrack : Direction -> TrackConfig -> CarAt -> Svg msg
renderCarOnTrack direction config car =
    let
        coords =
            coordinatesOnTrack direction config car
    in
    renderCar direction car coords


coordinatesOnTrack : Direction -> TrackConfig -> CarAt -> { angle : Float, x : Float, y : Float }
coordinatesOnTrack direction config car =
    let
        { cx, cy, r } =
            constants.track

        progress =
            Config.computeProgress config car

        angle =
            Scale.convert (progressToAngleScale direction) progress
    in
    { angle = angle
    , x = cx + r * cos angle
    , y = cy + r * sin angle
    }


renderCar : Direction -> CarAt -> { angle : Float, x : Float, y : Float } -> Svg msg
renderCar direction car { angle, x, y } =
    let
        { cx, cy } =
            constants.track

        labelRadius =
            constants.car.labelRadius

        labelX =
            cx + labelRadius * cos angle

        labelY =
            cy + labelRadius * sin angle
    in
    g []
        [ g [ Attributes.transform [ Translate x y ] ]
            -- Lazy compares its arguments by reference equality (===). A Css.Color record is
            -- recreated on every compute, so pass a String, which compares by value.
            [ Lazy.lazy2 carMarker car.standing.positionInClass (Class.toColor car.metadata.class).value ]
        , carLabel car.standing.positionInClass { x = labelX, y = labelY } { carNumber = car.metadata.carNumber }
        ]


carMarker : Int -> String -> Svg msg
carMarker positionInClass classColorValue =
    let
        scaleFactor =
            max 0.4 (1 - (toFloat positionInClass * 0.1))

        carSize =
            constants.car.size * scaleFactor

        saturation =
            if positionInClass <= 3 then
                "100%"

            else
                "50%"
    in
    circle
        [ Attributes.cx (px 0)
        , Attributes.cy (px 0)
        , Attributes.r (px carSize)
        , fill classColorValue
        , css [ Css.property "filter" ("saturate(" ++ saturation ++ ")") ]
        ]
        []


carLabel : Int -> { x : Float, y : Float } -> { carNumber : String } -> Svg msg
carLabel positionInClass { x, y } { carNumber } =
    let
        scaleFactor =
            max 0.75 (1 - (toFloat positionInClass * 0.02))
    in
    text_
        [ Attributes.x (px x)
        , Attributes.y (px y)
        , fontSize (px (constants.car.labelFontSize * scaleFactor))
        , textAnchor "middle"
        , dominantBaseline "central"
        , fill "oklch(1 0 0 / 0.7)"
        ]
        [ text carNumber ]
