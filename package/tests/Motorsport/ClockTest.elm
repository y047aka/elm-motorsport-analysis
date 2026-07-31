module Motorsport.ClockTest exposing (tests)

import Expect
import Motorsport.Clock as Clock
import Test exposing (..)
import Time exposing (millisToPosix)


{-| `setElapsed` is dispatched from the lap slider, which derives the moment from
the lap data rather than from the wall clock.
-}
epoch : Time.Posix
epoch =
    millisToPosix 0


tests : Test
tests =
    describe "Motorsport.Clock"
        [ describe "setElapsed"
            [ test "moves a clock that has never been started" <|
                \_ ->
                    Clock.init
                        |> Clock.setElapsed 39742950
                        |> Clock.getElapsed
                        |> Expect.equal 39742950
            , test "leaves the clock stopped, so it does not run on from where it was put" <|
                \_ ->
                    Clock.init
                        |> Clock.setElapsed 39742950
                        |> Clock.update (millisToPosix 5000) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal 39742950
            , test "carries the moment it was moved to into playback" <|
                \_ ->
                    Clock.init
                        |> Clock.setElapsed 39742950
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 5000) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal (39742950 + 5000)
            , test "moves a paused clock" <|
                \_ ->
                    Clock.init
                        |> Clock.update epoch Clock.Start
                        |> Clock.update epoch Clock.Pause
                        |> Clock.setElapsed 1000
                        |> Clock.getElapsed
                        |> Expect.equal 1000
            , test "moves a running clock to the moment asked for, not past it" <|
                \_ ->
                    -- Five minutes into playback, asked to go back to 1.000.
                    Clock.init
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 300000) Clock.Tick
                        |> Clock.setElapsed 1000
                        |> Clock.getElapsed
                        |> Expect.equal 1000
            , test "the moment asked for is not scaled by the playback speed" <|
                \_ ->
                    Clock.init
                        |> Clock.setPlaybackSpeed Clock.Speed60x
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 60000) Clock.Tick
                        |> Clock.setElapsed 1000
                        |> Clock.getElapsed
                        |> Expect.equal 1000
            , test "a running clock carries on from where it was moved to" <|
                \_ ->
                    Clock.init
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 300000) Clock.Tick
                        |> Clock.setElapsed 1000
                        |> Clock.update (millisToPosix 305000) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal (1000 + 5000)
            ]
        ]
