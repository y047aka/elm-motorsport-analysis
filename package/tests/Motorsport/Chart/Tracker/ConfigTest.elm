module Motorsport.Chart.Tracker.ConfigTest exposing (tests)

import Expect
import Motorsport.Chart.Tracker.Config as Config exposing (MiniSectorShares(..), TrackConfig)
import Motorsport.Wec.Circuit.Layout exposing (MiniSectorLines(..), TimingLines)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector(..))
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Motorsport.Chart.Tracker.Config"
        [ describe "toMetres"
            [ test "runs straight between two lines at the sector grain" <|
                \_ ->
                    [ 0.1, 0.35, 0.75 ]
                        |> List.map (Config.toMetres (Config.lapScale sectorLines bySectors))
                        |> expectAll [ 500, 2500, 7000 ]
            , test "puts a line with no distance where the time between its neighbours does" <|
                \_ ->
                    -- IP1 ends the third of fifteen even stretches, and is the
                    -- first line with a distance: SCL2's end is a third of it.
                    Config.toMetres (Config.lapScale miniSectorLines byMiniSectors) (1 / 15)
                        |> Expect.within (Expect.Absolute 0.001) 600
            , test "pins the scale to every line with a distance" <|
                \_ ->
                    Config.toMetres (Config.lapScale miniSectorLines byMiniSectors) (7 / 15)
                        |> Expect.within (Expect.Absolute 0.001) 6000
            , test "is not pinned to a stretch no lap has set a time for" <|
                \_ ->
                    -- IP2's stretch takes no share, so its line would pin two
                    -- distances to one progress.
                    Config.toMetres (Config.lapScale miniSectorLines withoutIp2) (7 / 15)
                        |> Expect.within (Expect.Absolute 0.001) (1800 + (4 / 12) * (12000 - 1800))
            ]
        , describe "the grain a round and its circuit disagree on"
            [
                -- `lapScale` reads the finer grain only when the round is timed
                -- at it *and* the circuit places the lines; each of these two
                -- combinations answers at the sector grain.
                test "a round timed finer than its circuit places lines" <|
                \_ ->
                    -- Nothing finer than 1,000, 4,000 and 10,000 m is placed,
                    -- and these interpolate those three distances.
                    [ 0.1, 0.35, 0.75 ]
                        |> List.map (Config.toMetres (Config.lapScale sectorsOnlyLines byMiniSectors))
                        |> expectAll [ 500, 2687.5, 7187.5 ]
            , test "lines the circuit places that no round was timed across" <|
                \_ ->
                    -- Fifteen lines placed and a lap split three ways: these
                    -- interpolate 1,800, 6,000 and 12,000 m.
                    [ 0.1, 0.35, 0.75 ]
                        |> List.map (Config.toMetres (Config.lapScale miniSectorLines bySectors))
                        |> expectAll [ 900, 3900, 9000 ]
            ]
        ]


expectAll : List Float -> List Float -> Expect.Expectation
expectAll expected actual =
    Expect.all
        ((\_ -> Expect.equal (List.length expected) (List.length actual))
            :: List.map2 (\e a -> \_ -> Expect.within (Expect.Absolute 0.001) e a) expected actual
        )
        ()


bySectors : TrackConfig
bySectors =
    { sectors =
        { s1 = { start = 0, share = 0.2 }
        , s2 = { start = 0.2, share = 0.3 }
        , s3 = { start = 0.5, share = 0.5 }
        }
    , miniSectors = NoMiniSectors
    }


sectorLines : TimingLines
sectorLines =
    { sectors = { s1 = 1000, s2 = 4000, s3 = 10000 }
    , miniSectors = LeMansMiniSectors (LeMans.initialize (\_ -> Nothing))
    }


{-| The same three lines on a circuit that divides its lap no finer -- which is
 what a round whose feed carries mini-sector shares meets at COTA.
-}
sectorsOnlyLines : TimingLines
sectorsOnlyLines =
    { sectors = { s1 = 1000, s2 = 4000, s3 = 10000 }
    , miniSectors = SectorsOnly
    }


{-| Fifteen stretches taking a fifteenth of the lap each.
-}
byMiniSectors : TrackConfig
byMiniSectors =
    { sectors =
        { s1 = { start = 0, share = 3 / 15 }
        , s2 = { start = 3 / 15, share = 4 / 15 }
        , s3 = { start = 7 / 15, share = 8 / 15 }
        }
    , miniSectors =
        MiniSectorShares
            (LeMans.initialize
                (\mini ->
                    { start = toFloat (index mini) / 15, share = 1 / 15 }
                )
            )
    }


withoutIp2 : TrackConfig
withoutIp2 =
    { byMiniSectors
        | miniSectors =
            MiniSectorShares
                (LeMans.initialize
                    (\mini ->
                        { start = toFloat (index mini) / 15
                        , share =
                            if mini == IP2 then
                                0

                            else
                                1 / 15
                        }
                    )
                )
    }


{-| IP1, IP2 and the finish line.
-}
miniSectorLines : TimingLines
miniSectorLines =
    { sectors = { s1 = 1800, s2 = 6000, s3 = 12000 }
    , miniSectors =
        LeMansMiniSectors
            (LeMans.initialize
                (\mini ->
                    case mini of
                        IP1 ->
                            Just 1800

                        IP2 ->
                            Just 6000

                        FL ->
                            Just 12000

                        _ ->
                            Nothing
                )
            )
    }


index : LeMans2025MiniSector -> Int
index mini =
    LeMans.all
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, m ) -> m == mini)
        |> List.head
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 0
