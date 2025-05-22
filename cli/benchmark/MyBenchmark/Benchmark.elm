module MyBenchmark.Benchmark exposing (Benchmark(..))

{-| hey, don't publish me please!
-}

import Benchmark.LowLevel as LowLevel exposing (Operation)
import MyBenchmark.Status exposing (Status)


type Benchmark
    = Single String Operation Status
    | Series String (List ( String, Operation, Status ))
    | Group String (List Benchmark)
