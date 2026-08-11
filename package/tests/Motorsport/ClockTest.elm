module Motorsport.ClockTest exposing (tests)

import Expect
import Motorsport.Clock as Clock
import Motorsport.Instant as Instant exposing (Instant)
import Test exposing (..)
import Time exposing (millisToPosix)


{-| `setElapsed` is dispatched from the lap slider, which derives the moment from
the lap data rather than from the wall clock.
-}
epoch : Time.Posix
epoch =
    millisToPosix 0


instant : Int -> Instant
instant =
    Instant.fromDuration


{-| A clock over a race long enough that nothing in `setElapsed` below runs into
the end of it. Where the end is has its own tests.
-}
clock : Clock.Model
clock =
    Clock.init { finishedAt = instant 86400000 }


{-| Ten seconds of racing, so playback reaches the end of it in one tick.
-}
shortClock : Clock.Model
shortClock =
    Clock.init { finishedAt = instant 10000 }


tests : Test
tests =
    describe "Motorsport.Clock"
        [ describe "setElapsed"
            [ test "moves a clock that has never been started" <|
                \_ ->
                    clock
                        |> Clock.setElapsed (instant 39742950)
                        |> Clock.getElapsed
                        |> Expect.equal (instant 39742950)
            , test "leaves the clock stopped, so it does not run on from where it was put" <|
                \_ ->
                    clock
                        |> Clock.setElapsed (instant 39742950)
                        |> Clock.update (millisToPosix 5000) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal (instant 39742950)
            , test "carries the moment it was moved to into playback" <|
                \_ ->
                    clock
                        |> Clock.setElapsed (instant 39742950)
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 5000) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal (instant (39742950 + 5000))
            , test "moves a paused clock" <|
                \_ ->
                    clock
                        |> Clock.update epoch Clock.Start
                        |> Clock.update epoch Clock.Pause
                        |> Clock.setElapsed (instant 1000)
                        |> Clock.getElapsed
                        |> Expect.equal (instant 1000)
            , test "moves a running clock to the moment asked for, not past it" <|
                \_ ->
                    -- Five minutes into playback, asked to go back to 1.000.
                    clock
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 300000) Clock.Tick
                        |> Clock.setElapsed (instant 1000)
                        |> Clock.getElapsed
                        |> Expect.equal (instant 1000)
            , test "the moment asked for is not scaled by the playback speed" <|
                \_ ->
                    clock
                        |> Clock.setPlaybackSpeed Clock.Speed60x
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 60000) Clock.Tick
                        |> Clock.setElapsed (instant 1000)
                        |> Clock.getElapsed
                        |> Expect.equal (instant 1000)
            , test "a running clock carries on from where it was moved to" <|
                \_ ->
                    clock
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 300000) Clock.Tick
                        |> Clock.setElapsed (instant 1000)
                        |> Clock.update (millisToPosix 305000) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal (instant (1000 + 5000))
            ]
        , describe "the end of what there is to play"
            [ test "playback runs out there rather than past it" <|
                \_ ->
                    shortClock
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 20000) Clock.Tick
                        |> (\m -> ( m.state, Clock.getElapsed m ))
                        |> Expect.equal ( Clock.Finished, instant 10000 )
            , test "and stays there however long it is ticked for" <|
                \_ ->
                    shortClock
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 20000) Clock.Tick
                        |> Clock.update (millisToPosix 999999) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal (instant 10000)
            , test "a head put past the end lands on it" <|
                \_ ->
                    shortClock
                        |> Clock.setElapsed (instant 999999)
                        |> Clock.getElapsed
                        |> Expect.equal (instant 10000)
            , test "moving off the end leaves the head stopped, not running on from it" <|
                \_ ->
                    -- The wall clock keeps going while playback sits at the end.
                    -- A head moved off it that was still `Started` would report
                    -- all of that time the next time it was asked.
                    shortClock
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 20000) Clock.Tick
                        |> Clock.setElapsed (instant 1000)
                        |> Clock.update (millisToPosix 999999) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal (instant 1000)
            , test "and playing from there carries on from where it was put" <|
                \_ ->
                    shortClock
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 20000) Clock.Tick
                        |> Clock.setElapsed (instant 1000)
                        |> Clock.update (millisToPosix 999999) Clock.Start
                        |> Clock.update (millisToPosix 1004999) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal (instant (1000 + 5000))
            ]
        ]
