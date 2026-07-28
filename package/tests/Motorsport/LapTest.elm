module Motorsport.LapTest exposing (tests)

import Expect
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Sector as Sector exposing (Sector(..))
import Test exposing (..)


{-| A lap running from 4.000 to 10.000, split 1.000 / 2.000 / 3.000.
-}
lap : Lap
lap =
    { empty
        | time = 6000
        , elapsed = 10000
        , sector_1 = 1000
        , sector_2 = 2000
        , sector_3 = 3000
    }


empty : Lap
empty =
    Lap.empty


tests : Test
tests =
    describe "Motorsport.Lap"
        [ describe "sectors"
            [ test "starts each sector where the one before it ended" <|
                \_ ->
                    Lap.sectors lap
                        |> Sector.values
                        |> List.map .start
                        |> Expect.equal [ 4000, 5000, 7000 ]
            , test "measures the first sector from the start of the lap, not the previous lap record" <|
                \_ ->
                    (Lap.sectors lap).s1.start
                        |> Expect.equal (lap.elapsed - lap.time)
            , test "ends the last sector where the lap ended" <|
                \_ ->
                    (Lap.sectors lap).s3
                        |> (\segment -> segment.start + segment.time)
                        |> Expect.equal lap.elapsed
            ]
        , describe "currentSegment"
            [ test "picks the sector holding the moment, and hands over on the boundary" <|
                \_ ->
                    [ 4000, 4999, 5000, 6999, 7000, 9999 ]
                        |> List.map (\elapsed -> Lap.currentSector { elapsed = elapsed } lap)
                        |> Expect.equal [ S1, S1, S2, S2, S3, S3 ]
            , test "falls through to the last sector once the lap is over" <|
                \_ ->
                    Lap.currentSector { elapsed = 10000 } lap
                        |> Expect.equal S3
            , test "falls through to the last sector before the lap has begun" <|
                \_ ->
                    Lap.currentSector { elapsed = 3999 } lap
                        |> Expect.equal S3
            , test "agrees with sectorStart on where the current sector started" <|
                \_ ->
                    [ 4500, 6000, 8000 ]
                        |> List.map
                            (\elapsed ->
                                let
                                    ( sector, segment ) =
                                        Lap.currentSegment { elapsed = elapsed } lap
                                in
                                ( segment.start, Lap.sectorStart lap sector )
                            )
                        |> List.filter (\( a, b ) -> a /= b)
                        |> Expect.equalLists []
            ]
        ]
