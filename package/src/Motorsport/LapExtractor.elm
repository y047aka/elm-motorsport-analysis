module Motorsport.LapExtractor exposing (extractLapsFromTimelineEvents)

{-|

@docs extractLapsFromTimelineEvents

-}

import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Lap exposing (Lap)
import Motorsport.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)


{-| timeline\_eventsからlapsデータを抽出してCarsのlapsフィールドを再構築する

タイムラインイベントからラップデータを復元する処理：

1.  Startイベントから各車両の1周目のラップデータを取得
2.  LapCompletedイベントから各周の完了後の次周ラップデータを取得
3.  車両ごとにラップデータをソートし、lapsフィールドを更新

-}
extractLapsFromTimelineEvents : List TimelineEvent -> List Car -> List Car
extractLapsFromTimelineEvents timelineEvents cars =
    cars
        |> List.map
            (\car ->
                let
                    carEvents =
                        timelineEvents
                            |> List.filterMap
                                (\event ->
                                    case event.eventType of
                                        CarEvent carNumber carEventType ->
                                            if carNumber == car.metadata.carNumber then
                                                Just carEventType

                                            else
                                                Nothing

                                        _ ->
                                            Nothing
                                )

                    extractedLaps =
                        extractLapsFromCarEvents carEvents
                in
                { car | laps = extractedLaps }
            )


{-| 車両固有のイベントからlapsを抽出する
-}
extractLapsFromCarEvents : List CarEventType -> List Lap
extractLapsFromCarEvents carEvents =
    let
        lapsFromEvents =
            carEvents
                |> List.filterMap
                    (\eventType ->
                        case eventType of
                            Start { currentLap } ->
                                Just currentLap

                            LapCompleted _ { nextLap } ->
                                Just nextLap

                            _ ->
                                Nothing
                    )
    in
    lapsFromEvents
        |> List.Extra.uniqueBy .lap
        |> List.sortBy .lap
