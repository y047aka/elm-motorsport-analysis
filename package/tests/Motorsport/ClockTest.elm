module Motorsport.ClockTest exposing (tests)

import Expect
import Motorsport.Clock as Clock
import Test exposing (..)
import Time exposing (millisToPosix)


{-| `Set` is dispatched from the lap slider, which derives the moment from the
lap data rather than from the wall clock, so the time it passes is arbitrary.
-}
epoch : Time.Posix
epoch =
    millisToPosix 0


tests : Test
tests =
    describe "Motorsport.Clock"
        [ describe "Set"
            [ test "moves a clock that has never been started" <|
                \_ ->
                    Clock.init
                        |> Clock.update epoch (Clock.Set 39742950)
                        |> Clock.getElapsed
                        |> Expect.equal 39742950
            , test "leaves the clock stopped, so it does not run on from where it was put" <|
                \_ ->
                    Clock.init
                        |> Clock.update epoch (Clock.Set 39742950)
                        |> Clock.update (millisToPosix 5000) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal 39742950
            , test "carries the moment it was moved to into playback" <|
                \_ ->
                    Clock.init
                        |> Clock.update epoch (Clock.Set 39742950)
                        |> Clock.update epoch Clock.Start
                        |> Clock.update (millisToPosix 5000) Clock.Tick
                        |> Clock.getElapsed
                        |> Expect.equal (39742950 + 5000)
            , test "moves a paused clock" <|
                \_ ->
                    Clock.init
                        |> Clock.update epoch Clock.Start
                        |> Clock.update epoch Clock.Pause
                        |> Clock.update epoch (Clock.Set 1000)
                        |> Clock.getElapsed
                        |> Expect.equal 1000
            ]
        ]
