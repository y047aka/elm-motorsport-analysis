module View.FeedTest exposing (suite)

import Expect
import Test exposing (Test, describe, test)
import View.Feed as Feed


{-| The stamp a post carries, and where its bands change. The app's docstring
examples are run by no compiler -- `.#test` verifies the package's only -- so the
spellings `ago` claims are asserted here.
-}
suite : Test
suite =
    describe "Feed.ago"
        [ test "under a step is `now`" <|
            \_ ->
                [ 0, 14999 ]
                    |> List.map (\ms -> Feed.ago { now = ms, at = 0 })
                    |> Expect.equal [ "now", "now" ]
        , test "the first minute counts fifteen seconds" <|
            \_ ->
                [ 15000, 29999, 30000, 44999, 45000, 59999 ]
                    |> List.map (\ms -> Feed.ago { now = ms, at = 0 })
                    |> Expect.equal [ "15s", "15s", "30s", "30s", "45s", "45s" ]
        , test "the minute arrives at sixty seconds and not before" <|
            \_ ->
                [ 60000, 75000, 119999 ]
                    |> List.map (\ms -> Feed.ago { now = ms, at = 0 })
                    |> Expect.equal [ "1m", "1m", "1m" ]
        , test "minutes run out at the hour, and hours take over" <|
            \_ ->
                [ 750000, 3599999, 3600000, 10800000 ]
                    |> List.map (\ms -> Feed.ago { now = ms, at = 0 })
                    |> Expect.equal [ "12m", "59m", "1h", "3h" ]
        , test "a post ahead of the clock it is stamped against is `now`" <|
            \_ ->
                Feed.ago { now = 0, at = 5000 }
                    |> Expect.equal "now"
        , test "a clock bucketed to the step costs the stamp one step" <|
            \_ ->
                -- The caller hands the clock floored to `Feed.step`, which is how a
                -- post nearly half a minute old still stamps `now`.
                Feed.ago { now = 15000, at = 1 }
                    |> Expect.equal "now"
        ]
